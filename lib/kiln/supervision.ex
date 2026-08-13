defmodule Kiln.Supervision do
  @moduledoc """
  The narrow Wave 3 application boundary that supervises one Repository
  Recon Work Envelope.

  `Kiln.Supervision` is the single public boundary that:

    1. accepts an `engineering-system/work-envelope/v0` payload,
    2. validates it through `Kiln.WorkEnvelope`,
    3. binds the `work_id` to a durable Run identity,
    4. observes the target repository through
       `Kiln.RepositoryObservation`,
    5. decides `git.read` authority through `Kiln.Authority`,
    6. accepts the producer's observation completion,
    7. persists the result as an immutable Artifact and records Evidence
       through the merged P1-S02-T01 substrate, and
    8. produces an `engineering-system/run-result-envelope/v0` from the
       durable facts.

  The boundary performs no write to the target repository, no shell
  command, no provider call, and no Capability other than
  `repository-recon` with read-only `git.read` authority. The procedure
  itself runs in the Loadout process; Kiln only supervises and records
  what the procedure reports.

  ## Idempotency

  The supervisor reuses the existing `Kiln.Evidence.Store` idempotency
  model. The `Run` identity is bound to `WorkEnvelope.request_digest/1`
  so a retry with the same `work_id` and same semantic request returns
  the previously-bound Run. A retry with the same `work_id` but a
  materially different request returns an integrity-classified
  idempotency conflict before any durable write.

  ## Restart durability

  The supervisor is the source of truth. The Run, Artifact, Evidence,
  authority decision, and final Run Result facts all live in Kiln's
  Store. After process death, `inspect_run/2` reconstructs the durable
  facts from the journal.
  """

  alias Kiln.{Authority, RepositoryObservation, RunResultEnvelope, WorkEnvelope}
  alias Kiln.Artifact.Store, as: ArtifactStore
  alias Kiln.Artifact.PutRequest
  alias Kiln.Evidence
  alias Kiln.Evidence.RecordRequest
  alias Kiln.Evidence.Store, as: EvidenceStore
  alias Kiln.Store

  @schema_authority_artifact "kiln.authority.decision/v1"
  @schema_observation_artifact "kiln.repository_observation/v1"
  @accepted_capability "git.read"

  # ============================================================================
  # Public surface
  # ============================================================================

  @doc """
  Supervise one Repository Recon Work Envelope end-to-end.

  Accepts a parsed `engineering-system/work-envelope/v0` map. Returns a
  Run Result Envelope map describing the durable outcome, plus the
  durable Run id, Artifact id, Evidence id, and authority decision id
  the supervisor bound. The CLI calls this through
  `Kiln.Supervision.run/2`.

  ## Pipeline

    1. Validate the Work Envelope through `Kiln.WorkEnvelope.new/1`.
    2. Derive the idempotency `request_digest` for the envelope.
    3. Resolve or create the durable Run (idempotent).
    4. Observe the target repository.
    5. Decide `git.read` authority.
    6. Reject authority if the result is `:denied` and the producer
       asked for any other capability.
    7. Accept the procedure observation completion (producer-supplied).
    8. Persist Artifact + Evidence through the merged substrate.
    9. Produce the Run Result Envelope from durable facts.

  The supervisor never imports or hosts Loadout source. The procedure
  is invoked outside this boundary; Kiln records what the procedure
  reports.
  """
  @spec supervise(map(), keyword()) :: {:ok, RunResultEnvelope.t()} | {:error, term()}
  def supervise(work_envelope_attrs, opts \\ []) when is_map(work_envelope_attrs) do
    store = Keyword.fetch!(opts, :store)
    actor_id = Keyword.fetch!(opts, :actor_id)
    now = Keyword.get(opts, :now, default_now())
    git = Keyword.get(opts, :git, "git")
    uuid_v7 = Keyword.get(opts, :uuid_v7, &Kiln.Store.Uuid.v7/0)

    repository_root_resolver =
      Keyword.get(opts, :repository_root_resolver, &default_repository_root/1)

    with {:ok, envelope} <- WorkEnvelope.new(work_envelope_attrs),
         {:ok, request_digest} <- idempotency_request_digest(envelope),
         {:ok, run_id, _run_state} <-
           resolve_run_id(
             store,
             envelope.work_id,
             request_digest,
             now,
             uuid_v7,
             envelope.project_state.base_commit,
             envelope.project_state.workspace_state_digest,
             Enum.map(envelope.proof_obligations, & &1.id)
           ) do
      observation_root = repository_root_resolver.(envelope.project_state.repository)
      observation_opts = [git: git, now: now]

      case RepositoryObservation.observe(
             observation_root,
             envelope.project_state.workspace_state_digest,
             observation_opts
           ) do
        {:ok, observation} ->
          decisions =
            build_authority_decisions(
              envelope,
              observation,
              run_id,
              now,
              uuid_v7
            )

          denied_other =
            Enum.any?(decisions, fn decision ->
              decision.requested_capability != @accepted_capability
            end)

          if denied_other do
            finalize_blocked(
              store,
              envelope,
              run_id,
              observation,
              decisions,
              request_digest,
              now,
              actor_id,
              uuid_v7
            )
          else
            finalize_observation(
              store,
              envelope,
              run_id,
              observation,
              decisions,
              request_digest,
              now,
              actor_id,
              uuid_v7,
              opts
            )
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Reconstruct a previously supervised Run's durable facts.

  Returns the Run Result Envelope reconstructed from the durable
  Artifact and Evidence rows. After process death, this is how a
  client recovers the canonical outcome.
  """
  @spec inspect_run(map(), String.t()) :: {:ok, RunResultEnvelope.t()} | {:error, term()}
  def inspect_run(store, run_id) when is_binary(run_id) do
    with {:ok, artifact_ids} <- fetch_run_artifact_ids(store, run_id),
         {:ok, evidence_ids} <- fetch_run_evidence_ids(store, run_id),
         {:ok, work_id} <- fetch_run_work_id(store, run_id),
         {:ok, envelope} <-
           reconstruct_envelope(store, work_id, run_id, artifact_ids, evidence_ids) do
      {:ok, envelope}
    end
  end

  @doc """
  Look up the durable Run id for a `(work_id, request_digest)` pair.

  Returns `{:ok, run_id}` or `:none`. Used by tests and by clients that
  want to recover Run identity without performing a full inspection.
  """
  @spec lookup_run(map(), String.t(), String.t()) :: {:ok, String.t()} | :none | {:error, term()}
  def lookup_run(store, work_id, request_digest)
      when is_binary(work_id) and is_binary(request_digest) do
    query = "SELECT run_id FROM supervision_runs WHERE work_id = ?1 AND request_digest = ?2"

    case Store.Connection.query!(store.conn, query, [work_id, request_digest]) do
      [[run_id]] -> {:ok, run_id}
      [] -> :none
    end
  end

  @doc """
  Verify the durable `request_digest` recorded for `work_id`.

  Used by tests that prove same-work_id + same-semantic-request replay
  and same-work-id + different-request conflict.
  """
  @spec recorded_request_digest(map(), String.t()) :: {:ok, String.t()} | :none | {:error, term()}
  def recorded_request_digest(store, work_id) when is_binary(work_id) do
    case Store.Connection.query!(
           store.conn,
           "SELECT request_digest FROM supervision_runs WHERE work_id = ?1",
           [work_id]
         ) do
      [[digest]] -> {:ok, digest}
      [] -> :none
      rows when is_list(rows) -> {:error, {:multiple_runs, length(rows)}}
    end
  end

  @doc """
  Resolve the durable Run id by `work_id` alone.

  Returns `{:ok, run_id}` when exactly one durable Run exists for the
  work_id, `:none` when none exists, or `{:error, :multiple_runs}` when
  more than one exists.

  Accepts the producer's `input_state` (`base_commit`,
  `workspace_state_digest`) and the `proof_obligation_ids` list so the
  new durable columns are persisted on the initial row insert. A
  pre-existing row created by the previous schema (without these
  columns) is left untouched; the projection treats empty values as
  `unknown` per migration 0006.
  """
  @spec resolve_run_id(
          map(),
          String.t(),
          String.t(),
          String.t(),
          (-> String.t()),
          String.t(),
          String.t(),
          [String.t()]
        ) :: {:ok, String.t(), map()} | {:error, term()}
  def resolve_run_id(
        store,
        work_id,
        request_digest,
        now,
        uuid_v7_fun,
        base_commit,
        workspace_state_digest,
        proof_obligation_ids
      )
      when is_binary(work_id) and is_binary(request_digest) and is_binary(base_commit) and
             is_binary(workspace_state_digest) and is_list(proof_obligation_ids) do
    obligation_ids_json = encode_obligations(proof_obligation_ids)

    case Store.Connection.query!(
           store.conn,
           "SELECT run_id, request_digest FROM supervision_runs WHERE work_id = ?1",
           [work_id]
         ) do
      [] ->
        run_id = uuid_v7_fun.()

        Store.Connection.query!(
          store.conn,
          """
          INSERT INTO supervision_runs (
            work_id, run_id, request_digest, created_at, run_state,
            base_commit, workspace_state_digest, proof_obligation_ids
          )
          VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
          """,
          [
            work_id,
            run_id,
            request_digest,
            now,
            "active",
            base_commit,
            workspace_state_digest,
            obligation_ids_json
          ]
        )

        {:ok, run_id, %{status: :created}}

      [[existing_run_id, existing_digest]] ->
        if existing_digest == request_digest do
          {:ok, existing_run_id, %{status: :replayed}}
        else
          {:error, {:idempotency_conflict, :different_request_for_same_work_id, existing_digest}}
        end

      rows ->
        {:error, {:multiple_runs, length(rows)}}
    end
  end

  # ============================================================================
  # Pipeline helpers
  # ============================================================================

  defp idempotency_request_digest(envelope) do
    {:ok, WorkEnvelope.request_digest(envelope)}
  end

  defp build_authority_decisions(envelope, observation, run_id, now, uuid_v7_fun) do
    Enum.map(envelope.authority_requests, fn request ->
      decision_id = uuid_v7_fun.()
      cap = request["capability"] || request[:capability]
      scope = request["scope"] || request[:scope]

      Authority.decide(
        work_id: envelope.work_id,
        run_id: run_id,
        requested_capability: cap,
        requested_scope: scope,
        observation: observation,
        base_commit: envelope.project_state.base_commit,
        decision_id: decision_id,
        now: now
      )
      |> case do
        {:ok, decision} -> decision
        {:error, _} -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp finalize_observation(
         store,
         envelope,
         run_id,
         observation,
         decisions,
         request_digest,
         now,
         actor_id,
         uuid_v7_fun,
         opts
       ) do
    observation_completion = Keyword.fetch!(opts, :observation_completion)

    case existing_run_evidence_ids(store, run_id) do
      {:ok, [_ | _] = evidence_ids} ->
        artifact_ids = existing_run_artifact_ids(store, run_id)

        build_envelope(
          store,
          envelope,
          run_id,
          observation,
          decisions,
          artifact_ids,
          evidence_ids,
          request_digest,
          observation_completion,
          actor_id,
          now,
          uuid_v7_fun
        )

      _ ->
        with {:ok, artifact_ids} <-
               persist_artifacts(
                 store,
                 envelope,
                 run_id,
                 observation,
                 decisions,
                 now,
                 uuid_v7_fun
               ),
             {:ok, evidence_ids} <-
               persist_evidence(
                 store,
                 envelope,
                 run_id,
                 observation,
                 decisions,
                 artifact_ids,
                 now,
                 uuid_v7_fun
               ) do
          build_envelope(
            store,
            envelope,
            run_id,
            observation,
            decisions,
            artifact_ids,
            evidence_ids,
            request_digest,
            observation_completion,
            actor_id,
            now,
            uuid_v7_fun
          )
        end
    end
  end

  defp existing_run_evidence_ids(store, run_id) do
    rows =
      Store.Connection.query!(
        store.conn,
        "SELECT evidence_id FROM supervision_run_evidence WHERE run_id = ?1 ORDER BY position",
        [run_id]
      )

    {:ok, Enum.map(rows, fn [id] -> id end)}
  end

  defp existing_run_artifact_ids(store, run_id) do
    rows =
      Store.Connection.query!(
        store.conn,
        "SELECT artifact_id FROM supervision_run_artifacts WHERE run_id = ?1 ORDER BY position",
        [run_id]
      )

    Enum.map(rows, fn [id] -> id end)
  end

  defp finalize_blocked(
         store,
         envelope,
         run_id,
         observation,
         decisions,
         _request_digest,
         now,
         _actor_id,
         uuid_v7_fun
       ) do
    artifact_ids =
      decisions
      |> Enum.with_index()
      |> Enum.map(fn {decision, index} ->
        publish_authority_artifact(store, decision, run_id, now, uuid_v7_fun, index + 1)
      end)
      |> Enum.reject(&is_nil/1)

    evidence_ids = []

    proof_obligations = %{
      satisfied: [],
      unsatisfied: Enum.map(envelope.proof_obligations, & &1.id),
      invalidated: []
    }

    effects =
      artifact_ids
      |> Enum.map(fn artifact_id ->
        %{"kind" => "authority_decision", "artifact_id" => artifact_id}
      end)

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
      effects: effects,
      evidence: evidence_ids,
      proof_obligations: proof_obligations,
      unknowns: [
        "authority was denied because the requested capabilities exceed the accepted v0 set"
      ]
    )
    |> case do
      {:ok, envelope} -> {:ok, envelope}
      {:error, _} = err -> err
    end
  end

  defp build_envelope(
         store,
         envelope,
         run_id,
         observation,
         decisions,
         artifact_ids,
         evidence_ids,
         _request_digest,
         observation_completion,
         _actor_id,
         now,
         uuid_v7_fun
       ) do
    granted = Enum.any?(decisions, &(&1.result == :granted))
    status = if granted, do: determine_status(observation_completion), else: :blocked

    proof_obligations =
      build_proof_obligations(envelope, observation_completion, status)

    effects =
      Enum.map(artifact_ids, fn artifact_id ->
        %{"kind" => "authority_decision", "artifact_id" => artifact_id}
      end) ++
        observation_completion_effects(observation_completion, uuid_v7_fun)

    unknowns = build_unknowns(envelope, observation_completion, now)

    case fetch_evidence_records(store, evidence_ids) do
      {:ok, evidence_by_id} ->
        evidence = evidence_summaries(evidence_ids, evidence_by_id)

        RunResultEnvelope.build(
          work_id: envelope.work_id,
          run_id: run_id,
          status: status,
          input_state: %{
            base_commit: envelope.project_state.base_commit,
            workspace_state_digest: envelope.project_state.workspace_state_digest
          },
          final_state: %{
            commit: observation.current_commit,
            workspace_state_digest: envelope.project_state.workspace_state_digest
          },
          authority_decisions: decisions,
          effects: effects,
          evidence: evidence,
          proof_obligations: proof_obligations,
          unknowns: unknowns
        )

      {:error, _} = err ->
        err
    end
  end

  defp determine_status(%{status: status}) when is_atom(status), do: status
  defp determine_status(%{"status" => status}) when is_binary(status), do: safe_to_atom(status)
  defp determine_status(_), do: :completed

  defp safe_to_atom("completed"), do: :completed
  defp safe_to_atom("blocked"), do: :blocked
  defp safe_to_atom("failed"), do: :failed
  defp safe_to_atom(_), do: :unknown

  defp build_proof_obligations(envelope, observation_completion, status) do
    satisfied_ids = Enum.map(envelope.proof_obligations, & &1.id)

    invalidated =
      if status != :completed do
        satisfied_ids
      else
        case observation_completion do
          %{status: :failed} -> satisfied_ids
          _ -> []
        end
      end

    %{
      satisfied: if(status == :completed, do: satisfied_ids, else: []),
      unsatisfied: if(status == :blocked, do: satisfied_ids, else: []),
      invalidated: invalidated
    }
  end

  defp observation_completion_effects(_observation_completion, _uuid_v7_fun), do: []

  defp build_unknowns(_envelope, observation_completion, _now) do
    base = []

    base =
      case observation_completion do
        %{warnings: warnings} when is_list(warnings) -> base ++ warnings
        _ -> base
      end

    case observation_completion do
      %{unknowns: unknowns} when is_list(unknowns) -> base ++ unknowns
      _ -> base
    end
    |> Enum.uniq()
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&to_string/1)
    |> Kernel.++([
      "Kiln-observed repository_state_digest is not claimed to equal the producer workspace_state_digest",
      "producer input_state preserved separately from kiln repository_state_digest"
    ])
    |> Enum.uniq()
  end

  # ============================================================================
  # Persistence helpers
  # ============================================================================

  defp persist_artifacts(store, _envelope, run_id, observation, decisions, now, uuid_v7_fun) do
    decisions_with_positions =
      decisions
      |> Enum.with_index()
      |> Enum.map(fn {decision, index} -> {decision, index + 1} end)

    ids =
      [publish_observation_artifact(store, observation, run_id, now, uuid_v7_fun)] ++
        Enum.map(decisions_with_positions, fn {decision, position} ->
          publish_authority_artifact(store, decision, run_id, now, uuid_v7_fun, position)
        end)

    {:ok, Enum.reject(ids, &is_nil/1)}
  end

  defp link_artifact(store, run_id, artifact_id, position) do
    Store.Connection.query!(
      store.conn,
      """
      INSERT OR IGNORE INTO supervision_run_artifacts (run_id, artifact_id, position)
      VALUES (?1, ?2, ?3)
      """,
      [run_id, artifact_id, position]
    )

    :ok
  end

  defp link_evidence(store, run_id, evidence_id, position) do
    Store.Connection.query!(
      store.conn,
      """
      INSERT OR IGNORE INTO supervision_run_evidence (run_id, evidence_id, position)
      VALUES (?1, ?2, ?3)
      """,
      [run_id, evidence_id, position]
    )

    :ok
  end

  defp publish_observation_artifact(store, observation, run_id, now, uuid_v7_fun) do
    body = %{
      "schema" => @schema_observation_artifact,
      "repository" => observation.repository,
      "current_commit" => observation.current_commit,
      "repository_state_digest" => observation.repository_state_digest,
      "input_state_digest" => observation.input_state_digest,
      "observed_at" => observation.observed_at,
      "head_resolved" => observation.head_resolved
    }

    bytes = JSON.encode!(body)

    artifact_id = uuid_v7_fun.()

    request = %PutRequest{
      artifact_id: artifact_id,
      bytes: bytes,
      metadata: %{
        session_id: "supervision",
        run_id: run_id,
        owner_kind: :run,
        owner_id: run_id,
        producer_kind: :deterministic_service,
        producer_id: "kiln.supervision.observation",
        kind: :report,
        media_type: "application/json",
        encoding: :utf_8,
        trust: :kiln_generated,
        sensitivity: :project,
        retention_class: :run,
        completeness: :complete,
        repository_state_digest: observation.repository_state_digest,
        host_profile_digest: nil
      },
      idempotency_key: "observation:" <> run_id,
      recorded_at: now
    }

    case ArtifactStore.put(store, request) do
      {:ok, _artifact, %{status: status}} when status in [:committed, :replayed] ->
        link_artifact(store, run_id, artifact_id, 0)
        artifact_id

      _ ->
        nil
    end
  end

  defp publish_authority_artifact(store, decision, run_id, now, uuid_v7_fun, position) do
    body = %{
      "schema" => @schema_authority_artifact,
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
    }

    bytes = JSON.encode!(body)
    artifact_id = uuid_v7_fun.()

    request = %PutRequest{
      artifact_id: artifact_id,
      bytes: bytes,
      metadata: %{
        session_id: "supervision",
        run_id: run_id,
        owner_kind: :run,
        owner_id: run_id,
        producer_kind: :deterministic_service,
        producer_id: "kiln.supervision.authority",
        kind: :report,
        media_type: "application/json",
        encoding: :utf_8,
        trust: :kiln_generated,
        sensitivity: :project,
        retention_class: :run,
        completeness: :complete,
        repository_state_digest: decision.repository_state_digest,
        host_profile_digest: nil
      },
      idempotency_key: "authority:" <> decision.decision_id,
      recorded_at: now
    }

    case ArtifactStore.put(store, request) do
      {:ok, _artifact, %{status: status}} when status in [:committed, :replayed] ->
        link_artifact(store, run_id, artifact_id, position)
        artifact_id

      _ ->
        nil
    end
  end

  defp persist_evidence(
         store,
         envelope,
         run_id,
         observation,
         decisions,
         artifact_ids,
         now,
         uuid_v7_fun
       ) do
    granted = Enum.any?(decisions, &(&1.result == :granted))

    if granted do
      evidence_attrs = %{
        evidence_id: uuid_v7_fun.(),
        session_id: "supervision",
        run_id: run_id,
        criterion_id: "repo-state-observed",
        criterion_revision: "v0",
        subject_id: run_id,
        subject_kind: :repository,
        subject_state_digest: observation.repository_state_digest,
        producer_kind: :deterministic_service,
        producer_id: "kiln.supervision",
        method: :repository_observation,
        result: :pass,
        repository_state_digest: observation.repository_state_digest,
        patch_id: nil,
        patch_digest: nil,
        patch_result_digest: nil,
        host_profile_digest: nil,
        command_registration_digest: nil,
        command_result_id: nil,
        artifact_ids: artifact_ids |> Enum.sort() |> Enum.uniq(),
        evaluator_digest:
          "sha256:" <>
            (:crypto.hash(:sha256, "kiln.supervision.evaluator") |> Base.encode16(case: :lower)),
        observation_digest:
          "sha256:" <>
            (:crypto.hash(:sha256, envelope.project_state.base_commit)
             |> Base.encode16(case: :lower)),
        completeness: :complete,
        freshness_rule: :same_repository_state,
        observed_at: observation.observed_at,
        recorded_at: now,
        rationale:
          "Wave 3 supervisor derived repo-state-observed evidence from a Repository Observation.",
        idempotency_key: "evidence:" <> run_id
      }

      case Evidence.new(evidence_attrs) do
        {:ok, evidence} ->
          request = %RecordRequest{
            evidence: evidence,
            admission_context: nil,
            warnings: []
          }

          case EvidenceStore.record(store, request) do
            {:ok, _evidence, %{status: status}} when status in [:committed, :replayed] ->
              link_evidence(store, run_id, evidence.evidence_id, 0)
              {:ok, [evidence.evidence_id]}

            {:error, reason} ->
              {:error, reason}
          end

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:ok, []}
    end
  end

  # ============================================================================
  # Reconstruct helpers (restart durability)
  # ============================================================================

  defp fetch_run_artifact_ids(store, run_id) do
    rows =
      Store.Connection.query!(
        store.conn,
        "SELECT artifact_id FROM supervision_run_artifacts WHERE run_id = ?1 ORDER BY artifact_id",
        [run_id]
      )

    {:ok, Enum.map(rows, fn [id] -> id end)}
  end

  defp fetch_run_evidence_ids(store, run_id) do
    rows =
      Store.Connection.query!(
        store.conn,
        "SELECT evidence_id FROM supervision_run_evidence WHERE run_id = ?1 ORDER BY evidence_id",
        [run_id]
      )

    {:ok, Enum.map(rows, fn [id] -> id end)}
  end

  defp fetch_run_work_id(store, run_id) do
    case Store.Connection.query!(
           store.conn,
           "SELECT work_id FROM supervision_runs WHERE run_id = ?1",
           [run_id]
         ) do
      [[work_id]] -> {:ok, work_id}
      [] -> {:error, :run_not_found}
    end
  end

  # Restore the persisted input bindings (base_commit,
  # workspace_state_digest, proof_obligation_ids) for one Run. Returns
  # `{:ok, %{base_commit, workspace_state_digest, proof_obligation_ids}}`
  # or `{:error, :run_not_found}`. A row written by the pre-0006 schema
  # has empty defaults; the caller must surface those as `:unknown`
  # rather than fabricating values.
  defp fetch_run_input_state(store, run_id) do
    case Store.Connection.query!(
           store.conn,
           """
           SELECT base_commit, workspace_state_digest, proof_obligation_ids
           FROM supervision_runs
           WHERE run_id = ?1
           """,
           [run_id]
         ) do
      [[base_commit, workspace_state_digest, obligation_ids_json]] ->
        {:ok,
         %{
           base_commit: base_commit,
           workspace_state_digest: workspace_state_digest,
           proof_obligation_ids: decode_obligations(obligation_ids_json)
         }}

      [] ->
        {:error, :run_not_found}
    end
  end

  defp decode_obligations("[]"), do: []
  defp decode_obligations(""), do: []

  defp decode_obligations(json) when is_binary(json) do
    case JSON.decode(json) do
      {:ok, list} when is_list(list) -> Enum.map(list, &to_string/1)
      _ -> []
    end
  end

  defp encode_obligations(ids) when is_list(ids) do
    JSON.encode!(Enum.map(ids, &to_string/1))
  end

  # The reconstruction pipeline. Every field is sourced from a durable
  # fact; the Artifact substrate is the accepted source for the
  # semantic payload of the Run, and `supervision_runs` is the source
  # for the producer's input bindings. A missing, corrupt, or unreadable
  # artifact yields `{:error, reason}`; a partially-recoverable Run
  # yields an envelope that classifies itself as `:unknown` and lists
  # the missing facts in `unknowns`.
  defp reconstruct_envelope(store, work_id, run_id, artifact_ids, evidence_ids) do
    with {:ok, input_state_row} <- fetch_run_input_state(store, run_id),
         {:ok, observation} <- find_observation_artifact(store, artifact_ids),
         {:ok, decisions} <- find_authority_decision_artifacts(store, artifact_ids),
         {:ok, evidence_by_id} <- fetch_evidence_records(store, evidence_ids) do
      # Decisions are ordered by artifact_id, not by submission time, so
      # the reconstructed envelope is deterministic.
      requested_caps =
        decisions
        |> Enum.map(& &1["requested_capability"])
        |> Enum.uniq()
        |> Enum.sort()

      granted_caps =
        decisions
        |> Enum.filter(&(&1["result"] == "granted"))
        |> Enum.map(& &1["requested_capability"])
        |> Enum.uniq()
        |> Enum.sort()

      denied_caps =
        decisions
        |> Enum.filter(&(&1["result"] == "denied"))
        |> Enum.map(& &1["requested_capability"])
        |> Enum.uniq()
        |> Enum.sort()

      authority = %{requested: requested_caps, granted: granted_caps, denied: denied_caps}

      final_state_commit = observation["current_commit"]

      final_state = %{
        commit: final_state_commit,
        workspace_state_digest: observation["input_state_digest"]
      }

      input_state = %{
        base_commit: input_state_row.base_commit,
        workspace_state_digest: input_state_row.workspace_state_digest
      }

      status = derive_status(decisions, evidence_by_id)

      proof_obligations =
        derive_proof_obligations(input_state_row.proof_obligation_ids, evidence_by_id)

      unknowns = build_reconstruction_unknowns(input_state_row, observation, decisions)

      envelope = %RunResultEnvelope{
        schema: RunResultEnvelope.schema(),
        work_id: work_id,
        run_id: run_id,
        status: status,
        input_state: input_state,
        final_state: final_state,
        authority: authority,
        effects:
          Enum.map(artifact_ids, fn id -> %{"kind" => "artifact", "artifact_id" => id} end),
        evidence: evidence_summaries(evidence_ids, evidence_by_id),
        proof_obligations: proof_obligations,
        unknowns: unknowns,
        recovery: nil,
        acceptance_readiness: %{
          ready: false,
          reasons: ["reconstructed envelope never claims user acceptance"]
        }
      }

      {:ok, envelope}
    else
      {:error, :run_not_found} ->
        {:error, :run_not_found}

      {:error, {:missing_artifact, _kind}} ->
        {:error, {:incomplete_durable_facts, "required artifact is missing"}}

      {:error, {:corrupt_artifact, artifact_id}} ->
        {:error, {:incomplete_durable_facts, "artifact #{artifact_id} failed integrity check"}}

      {:error, %Kiln.Store.Error{class: :integrity} = err} ->
        {:error, {:incomplete_durable_facts, "artifact failed integrity check: #{err.code}"}}

      {:error, %Kiln.Store.Error{class: :io} = err} ->
        {:error, {:incomplete_durable_facts, "artifact unreadable: #{err.code}"}}
    end
  end

  # Locate the observation Artifact published by `publish_observation_artifact/6`
  # among the run's artifact ids. There is exactly one observation per
  # supervised Run; a supervisor that persisted zero or multiple is a
  # durable inconsistency and must not be silently repaired.
  defp find_observation_artifact(store, artifact_ids) do
    find_artifact_by_schema(store, artifact_ids, @schema_observation_artifact)
  end

  # Locate every authority_decision Artifact published for this Run.
  # The supervisor publishes one per Work Envelope `authority_request`
  # entry; a missing entry is an inconsistent supervision and is
  # surfaced as `{:error, {:missing_artifact, :authority_decision}}`.
  defp find_authority_decision_artifacts(store, artifact_ids) do
    case each_artifact(store, artifact_ids, fn body ->
           body["schema"] == @schema_authority_artifact
         end) do
      {:ok, decisions} ->
        if Enum.empty?(decisions) do
          {:error, {:missing_artifact, :authority_decision}}
        else
          {:ok, Enum.sort_by(decisions, & &1["decision_id"])}
        end

      {:error, _} = err ->
        err
    end
  end

  defp find_artifact_by_schema(store, artifact_ids, schema) do
    case each_artifact(store, artifact_ids, fn body -> body["schema"] == schema end) do
      {:ok, [body | _]} -> {:ok, body}
      {:ok, []} -> {:error, {:missing_artifact, schema}}
      err -> err
    end
  end

  # Read and decode each Artifact body whose schema predicate holds,
  # verifying integrity for every one before returning the decoded
  # payload. A corrupt or missing artifact body fails the whole
  # reconstruction; the supervisor must not decode and trust
  # unverified bytes.
  defp each_artifact(store, artifact_ids, schema_predicate) do
    Enum.reduce_while(artifact_ids, {:ok, []}, fn artifact_id, {:ok, acc} ->
      case read_and_decode_artifact(store, artifact_id) do
        {:ok, body} ->
          if schema_predicate.(body) do
            {:cont, {:ok, [body | acc]}}
          else
            {:cont, {:ok, acc}}
          end

        {:error, {:artifact_corrupt, ^artifact_id}} ->
          {:halt, {:error, {:corrupt_artifact, artifact_id}}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp read_and_decode_artifact(store, artifact_id) do
    case ArtifactStore.read(store, artifact_id) do
      {:ok, bytes, %{integrity_status: :verified}} ->
        case JSON.decode(bytes) do
          {:ok, body} when is_map(body) -> {:ok, body}
          _ -> {:error, {:artifact_corrupt, artifact_id}}
        end

      {:error, %Kiln.Store.Error{} = error} ->
        {:error, error}
    end
  end

  # Fetch every Evidence record bound to the Run, returning a map keyed
  # by `evidence_id`. Each Evidence row carries the immutable
  # `criterion_id` and `result` the supervisor needs to derive
  # `proof_obligations` truthfully.
  defp fetch_evidence_records(store, evidence_ids) do
    Enum.reduce_while(evidence_ids, {:ok, %{}}, fn evidence_id, {:ok, acc} ->
      case EvidenceStore.fetch(store, evidence_id) do
        {:ok, evidence, %{integrity_status: _status}} ->
          {:cont, {:ok, Map.put(acc, evidence_id, evidence)}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp evidence_summaries(evidence_ids, evidence_by_id) do
    Enum.map(evidence_ids, fn evidence_id ->
      evidence = Map.fetch!(evidence_by_id, evidence_id)

      %{
        "id" => evidence.evidence_id,
        "kind" => "evidence",
        "state_digest" => evidence.subject_state_digest
      }
    end)
  end

  defp derive_status(decisions, evidence_by_id) do
    cond do
      Enum.empty?(decisions) ->
        :unknown

      Enum.any?(decisions, &(&1["result"] == "denied")) ->
        :blocked

      evidence_by_id == %{} ->
        :unknown

      true ->
        :completed
    end
  end

  # Truthfully partition the Work Envelope's proof obligations. A
  # `pass` Evidence satisfies the obligation; a `fail` Evidence
  # invalidates it; the remaining obligations are unsatisfied. When the
  # supervisor persisted no obligation ids (pre-0006 schema), the
  # envelope reports the obligation set as unknown rather than
  # inventing one — the projection lists that fact in `unknowns`.
  defp derive_proof_obligations(obligation_ids, evidence_by_id) do
    if obligation_ids == [] do
      %{satisfied: [], unsatisfied: [], invalidated: [], unknown: true}
    else
      satisfied =
        evidence_by_id
        |> Map.values()
        |> Enum.filter(&(&1.result == :pass))
        |> Enum.map(& &1.criterion_id)
        |> Enum.filter(&(&1 in obligation_ids))
        |> Enum.sort()
        |> Enum.uniq()

      failed =
        evidence_by_id
        |> Map.values()
        |> Enum.filter(&(&1.result == :fail))
        |> Enum.map(& &1.criterion_id)
        |> Enum.filter(&(&1 in obligation_ids))
        |> Enum.sort()
        |> Enum.uniq()

      invalidated =
        obligation_ids
        |> Enum.filter(&(&1 in failed))
        |> Enum.sort()
        |> Enum.uniq()

      unsatisfied =
        obligation_ids
        |> Enum.reject(&(&1 in satisfied))
        |> Enum.reject(&(&1 in invalidated))
        |> Enum.sort()
        |> Enum.uniq()

      %{satisfied: satisfied, unsatisfied: unsatisfied, invalidated: invalidated, unknown: false}
    end
  end

  defp build_reconstruction_unknowns(input_state_row, observation, decisions) do
    base =
      [
        if(input_state_row.base_commit == "",
          do: "input_state.base_commit was not durably persisted",
          else: nil
        ),
        if(input_state_row.workspace_state_digest == "",
          do: "input_state.workspace_state_digest was not durably persisted",
          else: nil
        ),
        if(input_state_row.proof_obligation_ids == [],
          do: "proof_obligations were not durably persisted",
          else: nil
        ),
        if(observation["head_resolved"] == false,
          do: "observation.head_resolved was false at supervision time",
          else: nil
        )
      ]
      |> Enum.reject(&is_nil/1)

    decision_unknowns =
      decisions
      |> Enum.flat_map(fn decision ->
        if decision["granted_scope"] in [nil, ""] do
          ["authority_decision #{decision["decision_id"]} has no granted_scope recorded"]
        else
          []
        end
      end)

    (base ++
       decision_unknowns ++
       [
         "Kiln-observed repository_state_digest is not claimed to equal the producer workspace_state_digest",
         "producer input_state preserved separately from kiln repository_state_digest"
       ])
    |> Enum.uniq()
  end

  # ============================================================================
  # Default helpers
  # ============================================================================

  defp default_now do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end

  defp default_repository_root(repository) when is_binary(repository) do
    if File.exists?(repository), do: repository, else: repository
  end
end
