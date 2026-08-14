defmodule Kiln.Verification.Supervision do
  @moduledoc "Bounded execution and durable Evidence pipeline for Verify This Change."

  alias Kiln.{Authority, Evidence, RepositoryObservation, RunResultEnvelope, Store, WorkEnvelope}
  alias Kiln.Artifact.PutRequest
  alias Kiln.Artifact.Store, as: ArtifactStore
  alias Kiln.Evidence.RecordRequest
  alias Kiln.Evidence.Store, as: EvidenceStore
  alias Kiln.Verification.{Change, CommandHost, State}

  @observation_schema "kiln.repository_observation/v1"
  @authority_schema "kiln.authority.decision/v1"
  @result_schema "kiln.verification.command_result/v1"
  @stdout_schema "kiln.verification.stdout/v1"
  @stderr_schema "kiln.verification.stderr/v1"

  @spec supervise(map(), map(), keyword()) :: {:ok, RunResultEnvelope.t()} | {:error, term()}
  def supervise(envelope_attrs, change_attrs, opts) do
    store = Keyword.fetch!(opts, :store)
    now = Keyword.get(opts, :now, DateTime.utc_now() |> DateTime.to_iso8601())
    uuid = Keyword.get(opts, :uuid_v7, &Kiln.Store.Uuid.v7/0)
    git = Keyword.get(opts, :git, "git")

    with {:ok, envelope} <- WorkEnvelope.new(envelope_attrs),
         :ok <- ensure_capability(envelope),
         {:ok, change} <- Change.validate(change_attrs, envelope),
         request_digest <- WorkEnvelope.request_digest(envelope),
         {:ok, run_id, run_state} <-
           Kiln.Supervision.resolve_run_id(
             store,
             envelope.work_id,
             request_digest,
             now,
             uuid,
             envelope.project_state.base_commit,
             envelope.project_state.workspace_state_digest,
             Enum.map(envelope.proof_obligations, & &1.id)
           ) do
      if run_state.status == :replayed do
        Kiln.Supervision.inspect_run(store, run_id)
      else
        execute_new(store, envelope, change, run_id, now, uuid, git, opts)
      end
    else
      {:error, _} = error -> error
    end
  end

  defp execute_new(store, envelope, change, run_id, now, uuid, git, opts) do
    with {:ok, state_before} <-
           State.observe(change.repository, envelope.project_state.base_commit, git),
         :ok <- verify_initial_state(state_before, change),
         {:ok, observation} <-
           RepositoryObservation.observe(
             change.repository,
             envelope.project_state.workspace_state_digest,
             git: git,
             now: now
           ),
         decisions <- build_decisions(envelope, change, observation, run_id, now, uuid, opts),
         :ok <- require_grants(decisions),
         {:ok, base_artifacts} <-
           persist_base_artifacts(store, change, observation, decisions, run_id, now, uuid),
         {:ok, command_records} <- run_commands(change.commands, opts),
         {:ok, state_after} <-
           State.observe(change.repository, envelope.project_state.base_commit, git),
         :ok <- verify_unchanged_state(state_before, state_after),
         {:ok, command_artifacts} <-
           persist_command_artifacts(
             store,
             command_records,
             observation,
             run_id,
             now,
             uuid,
             length(base_artifacts)
           ),
         {:ok, _evidence_ids} <-
           persist_evidence(
             store,
             change,
             command_records,
             command_artifacts,
             observation,
             run_id,
             now,
             uuid
           ),
         {:ok, reconstructed} <- Kiln.Supervision.inspect_run(store, run_id) do
      {:ok, reconstructed}
    else
      {:error, {:authority_denied, decisions}} ->
        persist_denied_and_build(store, envelope, change, run_id, decisions, now, uuid)

      {:error, _} = error ->
        error
    end
  end

  defp build_decisions(envelope, change, observation, run_id, now, uuid, opts) do
    allowed = ["git.read" | Enum.map(change.commands, &("verification.run:" <> &1.id))]
    denied = Keyword.get(opts, :deny_capabilities, [])

    Enum.map(envelope.authority_requests, fn request ->
      requested_capability = request["capability"] || request[:capability]
      requested_scope = request["scope"] || request[:scope]

      {:ok, decision} =
        Authority.decide(
          work_id: envelope.work_id,
          run_id: run_id,
          requested_capability: requested_capability,
          requested_scope: requested_scope,
          observation: observation,
          base_commit: envelope.project_state.base_commit,
          decision_id: uuid.(),
          now: now,
          allowed_capabilities: allowed,
          denied_capabilities: denied
        )

      decision
    end)
  end

  defp ensure_capability(%WorkEnvelope{capability: %{id: "verify-change"}}), do: :ok
  defp ensure_capability(_envelope), do: {:error, :wrong_capability}

  defp require_grants(decisions) do
    if Enum.all?(decisions, &(&1.result == :granted)),
      do: :ok,
      else: {:error, {:authority_denied, decisions}}
  end

  defp run_commands(commands, opts) do
    host = Keyword.get(opts, :command_host, &CommandHost.run/2)
    host_opts = Keyword.get(opts, :command_host_opts, [])

    commands
    |> Enum.reduce_while({:ok, []}, fn command, {:ok, acc} ->
      case host.(command, host_opts) do
        {:ok, result} ->
          {:cont, {:ok, acc ++ [result]}}

        {:error, reason} ->
          {:halt, {:error, {:command_execution_unavailable, command.id, reason}}}
      end
    end)
  end

  defp verify_initial_state(state, change) do
    cond do
      state.head_commit != get_in(change.attrs, ["change", "current_state", "commit"]) ->
        {:error, :stale_verification_change_head}

      state.patch_digest != change.patch_digest ->
        {:error, :stale_verification_change_patch}

      true ->
        :ok
    end
  end

  defp verify_unchanged_state(before_state, after_state) do
    if before_state == after_state, do: :ok, else: {:error, :mid_run_repository_change}
  end

  defp persist_base_artifacts(store, change, observation, decisions, run_id, now, uuid) do
    records = [
      {change.attrs, "kiln.verification.request", :input, :user_supplied},
      {%{
         "schema" => @observation_schema,
         "repository" => observation.repository,
         "current_commit" => observation.current_commit,
         "repository_state_digest" => observation.repository_state_digest,
         "input_state_digest" => observation.input_state_digest,
         "observed_at" => observation.observed_at,
         "head_resolved" => observation.head_resolved
       }, "kiln.verification.observation", :snapshot, :repository_observation}
      | Enum.map(decisions, fn decision ->
          {%{
             "schema" => @authority_schema,
             "decision_id" => decision.decision_id,
             "work_id" => decision.work_id,
             "run_id" => decision.run_id,
             "requested_capability" => decision.requested_capability,
             "requested_scope" => decision.requested_scope,
             "granted_scope" => decision.granted_scope,
             "repository_state_digest" => decision.repository_state_digest,
             "result" => Atom.to_string(decision.result),
             "reason_code" => Atom.to_string(decision.reason_code),
             "decided_at" => decision.decided_at
           }, "kiln.verification.authority", :report, :kiln_generated}
        end)
    ]

    persist_json_records(
      store,
      records,
      observation.repository_state_digest,
      run_id,
      now,
      uuid,
      0
    )
  end

  defp persist_command_artifacts(store, records, observation, run_id, now, uuid, offset) do
    records
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {result, index}, {:ok, acc} ->
      command_result =
        result
        |> Map.drop([:stdout, :stderr, :result])
        |> Map.put(:schema, @result_schema)
        |> Map.put(:result, Atom.to_string(result.result))

      bodies = [
        {%{
           "schema" => @stdout_schema,
           "command_id" => result.command_id,
           "bytes_base64" => Base.encode64(result.stdout)
         }, "kiln.verification.command.stdout", :log, :registered_command_output},
        {%{
           "schema" => @stderr_schema,
           "command_id" => result.command_id,
           "bytes_base64" => Base.encode64(result.stderr)
         }, "kiln.verification.command.stderr", :log, :registered_command_output},
        {command_result, "kiln.verification.command.result", :report, :kiln_generated}
      ]

      case persist_json_records(
             store,
             bodies,
             observation.repository_state_digest,
             run_id,
             now,
             uuid,
             offset + index * 3
           ) do
        {:ok, ids} ->
          {:cont,
           {:ok, acc ++ [%{command_id: result.command_id, ids: ids, result_id: List.last(ids)}]}}

        {:error, _} = error ->
          {:halt, error}
      end
    end)
  end

  defp persist_json_records(store, records, state_digest, run_id, now, uuid, offset) do
    records
    |> Enum.with_index(offset)
    |> Enum.reduce_while({:ok, []}, fn {{body, producer_id, kind, trust}, position}, {:ok, ids} ->
      artifact_id = uuid.()

      request = %PutRequest{
        artifact_id: artifact_id,
        bytes: JSON.encode!(body),
        metadata: %{
          session_id: "verification",
          run_id: run_id,
          owner_kind: :run,
          owner_id: run_id,
          producer_kind: :deterministic_service,
          producer_id: producer_id,
          kind: kind,
          media_type: "application/json",
          encoding: :utf_8,
          trust: trust,
          sensitivity: :project,
          retention_class: :run,
          completeness: :complete,
          repository_state_digest: state_digest,
          host_profile_digest: nil
        },
        idempotency_key: "verification-artifact:#{run_id}:#{position}",
        recorded_at: now
      }

      case ArtifactStore.put(store, request) do
        {:ok, _artifact, %{status: status}} when status in [:committed, :replayed] ->
          link_artifact(store, run_id, artifact_id, position)
          {:cont, {:ok, ids ++ [artifact_id]}}

        {:error, _} = error ->
          {:halt, error}
      end
    end)
  end

  defp persist_evidence(store, change, results, artifacts, observation, run_id, now, uuid) do
    by_command = Map.new(results, &{&1.command_id, &1})
    artifacts_by_command = Map.new(artifacts, &{&1.command_id, &1})

    change.obligations
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {obligation, position}, {:ok, ids} ->
      required = obligation["required_commands"] || []

      {method, producer_kind, producer_id, result, registration, result_id, artifact_ids,
       host_digest, result_digest} =
        if required == [] do
          {:deterministic_validator, :deterministic_service, "kiln.verification.obligation",
           if(obligation["kind"] == "observation", do: :pass, else: :unknown), nil, nil, [], nil,
           digest(JSON.encode!(obligation))}
        else
          command_results = Enum.map(required, &Map.fetch!(by_command, &1))
          failed = Enum.any?(command_results, &(&1.result != :pass))
          first = hd(command_results)
          command_artifacts = Map.fetch!(artifacts_by_command, first.command_id)

          {:registered_command, :command, first.command_id, if(failed, do: :fail, else: :pass),
           first.registration_digest, command_artifacts.result_id, command_artifacts.ids,
           first.environment_digest, digest(JSON.encode!(Map.drop(first, [:stdout, :stderr])))}
        end

      evidence_attrs = %{
        evidence_id: uuid.(),
        session_id: "verification",
        run_id: run_id,
        criterion_id: obligation["id"],
        criterion_revision: "v0",
        subject_id: run_id,
        subject_kind: :run,
        subject_state_digest: observation.repository_state_digest,
        producer_kind: producer_kind,
        producer_id: producer_id,
        method: method,
        result: result,
        repository_state_digest: observation.repository_state_digest,
        patch_id: change.digest,
        patch_digest: change.patch_digest,
        patch_result_digest: result_digest,
        host_profile_digest: host_digest,
        command_registration_digest: registration,
        command_result_id: result_id,
        artifact_ids: artifact_ids,
        evaluator_digest: digest("kiln.verification.evaluator/v1"),
        observation_digest: digest(JSON.encode!(obligation)),
        completeness: :complete,
        freshness_rule:
          if(method == :registered_command,
            do: :same_command_registration_and_repository_state,
            else: :same_patch_and_repository_state
          ),
        observed_at: observation.observed_at,
        recorded_at: now,
        rationale: "Evidence is bound only to proof obligation #{obligation["id"]}.",
        idempotency_key: "verification-evidence:#{run_id}:#{obligation["id"]}"
      }

      with {:ok, evidence} <- Evidence.new(evidence_attrs),
           {:ok, _recorded, %{status: status}} when status in [:committed, :replayed] <-
             EvidenceStore.record(store, %RecordRequest{
               evidence: evidence,
               admission_context: nil,
               warnings: []
             }) do
        link_evidence(store, run_id, evidence.evidence_id, position)
        {:cont, {:ok, ids ++ [evidence.evidence_id]}}
      else
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp persist_denied_and_build(store, envelope, change, run_id, decisions, now, uuid) do
    observation = %RepositoryObservation{
      repository: change.repository,
      current_commit: envelope.project_state.base_commit,
      repository_state_digest: envelope.project_state.workspace_state_digest,
      input_state_digest: envelope.project_state.workspace_state_digest,
      observed_at: now,
      head_resolved: true
    }

    with {:ok, artifact_ids} <-
           persist_base_artifacts(store, change, observation, decisions, run_id, now, uuid) do
      RunResultEnvelope.build(
        work_id: envelope.work_id,
        run_id: run_id,
        status: :blocked,
        input_state: %{
          base_commit: envelope.project_state.base_commit,
          workspace_state_digest: envelope.project_state.workspace_state_digest
        },
        final_state: %{
          commit: observation.current_commit,
          workspace_state_digest: envelope.project_state.workspace_state_digest
        },
        authority_decisions: decisions,
        effects: Enum.map(artifact_ids, &%{"kind" => "artifact", "artifact_id" => &1}),
        evidence: [],
        proof_obligations: %{
          satisfied: [],
          unsatisfied: Enum.map(envelope.proof_obligations, & &1.id),
          invalidated: []
        },
        unknowns: ["verification authority was denied"],
        acceptance_readiness: %{
          ready: false,
          reasons: ["required verification authority was denied"]
        },
        verification_epistemic_state: :blocked,
        aggregate_evaluation: %{value: :not_ready, reason: :none}
      )
    end
  end

  defp link_artifact(store, run_id, artifact_id, position) do
    Store.Connection.query!(
      store.conn,
      "INSERT OR IGNORE INTO supervision_run_artifacts (run_id, artifact_id, position) VALUES (?1, ?2, ?3)",
      [run_id, artifact_id, position]
    )

    :ok
  end

  defp link_evidence(store, run_id, evidence_id, position) do
    Store.Connection.query!(
      store.conn,
      "INSERT OR IGNORE INTO supervision_run_evidence (run_id, evidence_id, position) VALUES (?1, ?2, ?3)",
      [run_id, evidence_id, position]
    )

    :ok
  end

  defp digest(bytes),
    do: "sha256:" <> (:crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower))
end
