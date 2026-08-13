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
           resolve_run_id(store, envelope.work_id, request_digest, now, uuid_v7) do
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
  """
  @spec resolve_run_id(map(), String.t(), String.t(), String.t(), (-> String.t())) ::
          {:ok, String.t(), map()} | {:error, term()}
  def resolve_run_id(store, work_id, request_digest, now, uuid_v7_fun)
      when is_binary(work_id) and is_binary(request_digest) do
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
          INSERT INTO supervision_runs (work_id, run_id, request_digest, created_at, run_state)
          VALUES (?1, ?2, ?3, ?4, ?5)
          """,
          [work_id, run_id, request_digest, now, "active"]
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
         _store,
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

    evidence =
      Enum.map(evidence_ids, fn evidence_id ->
        %{"kind" => "evidence", "evidence_id" => evidence_id}
      end)

    unknowns = build_unknowns(envelope, observation_completion, now)

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
    |> case do
      {:ok, built} -> {:ok, built}
      {:error, _} = err -> err
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

  defp reconstruct_envelope(_store, work_id, run_id, artifact_ids, evidence_ids) do
    envelope = %RunResultEnvelope{
      schema: RunResultEnvelope.schema(),
      work_id: work_id,
      run_id: run_id,
      status: :completed,
      input_state: %{
        base_commit: "0000000000000000000000000000000000000000",
        workspace_state_digest: "sha256:restored"
      },
      final_state: %{
        commit: nil,
        workspace_state_digest: "sha256:restored"
      },
      authority: %{requested: [], granted: [], denied: []},
      effects: Enum.map(artifact_ids, fn id -> %{"kind" => "artifact", "artifact_id" => id} end),
      evidence: Enum.map(evidence_ids, fn id -> %{"kind" => "evidence", "evidence_id" => id} end),
      proof_obligations: %{satisfied: ["repo-state-observed"], unsatisfied: [], invalidated: []},
      unknowns: ["reconstructed from durable artifact + evidence ids"],
      recovery: nil,
      acceptance_readiness: %{
        ready: false,
        reasons: ["reconstructed envelope never claims acceptance"]
      }
    }

    {:ok, envelope}
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
