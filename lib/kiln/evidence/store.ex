defmodule Kiln.Evidence.Store do
  @moduledoc """
  Durable Evidence persistence (P1-S02-T01-R05..R11, R15).

  ## Public surface

    * `record/2` — persist a RecordRequest, returning the immutable Evidence
      with `:committed` or `:replayed` status.
    * `fetch/2` — read and integrity-verify a previously committed Evidence.

  This module owns one outer `BEGIN IMMEDIATE` transaction and the
  admission / idempotency classification required by R06 and R11. It never
  opens a nested transaction, never invokes another write API, and never
  accepts a caller callback as transaction logic (P1-S02-T01-R13).

  ## Recording sequence

  1. Validate the RecordRequest envelope.
  2. Open one `BEGIN IMMEDIATE` transaction and classify the idempotency
     key.
  3. For a replay: compare stored `request_digest`; matching returns the
     stored record with `status: :replayed`; mismatched returns
     `:idempotency_conflict` and writes nothing.
  4. For an unseen key: evaluate `admission_context` (when supplied),
     integrity-verify every plural Artifact reference, then insert
     `evidence_records`, `evidence_artifacts`, and `evidence_warnings`.
  5. Commit the transaction; a fault at any write point rolls back the new
     Evidence row and all child rows while leaving prior Artifact and
     Evidence records unchanged.
  """

  alias Kiln.Evidence
  alias Kiln.Evidence.RecordRequest
  alias Kiln.Store.{Connection, Error}

  @type record_outcome :: {:ok, Evidence.t(), %{status: :committed | :replayed}}
  @type fetch_outcome :: {:ok, Evidence.t(), %{integrity_status: integrity_status()}}
  @type error_outcome :: {:error, Error.t()}

  @typep integrity_status :: :verified | :missing | :corrupt | :unreadable

  @doc """
  Persist an Evidence record.

  Returns `{:ok, evidence, %{status: :committed}}` for an unseen key or
  `{:ok, evidence, %{status: :replayed}}` for an exact idempotency retry.
  Conflicting reuse of an idempotency key returns
  `:idempotency_conflict` and writes nothing. A failed recording never
  leaves a partial Evidence row or orphaned child rows.
  """
  @spec record(map(), RecordRequest.t()) :: record_outcome() | error_outcome()
  def record(%{conn: conn} = _store, %RecordRequest{} = request) do
    Connection.transaction(conn, fn tx ->
      classify_and_apply(tx, request)
    end)
    |> finalize_record()
  end

  @doc """
  Fetch a previously committed Evidence record.

  Returns the persisted immutable record with a derived `integrity_status`:

    * `:verified` — every referenced Artifact metadata row exists and is
      unchanged;
    * `:missing` — at least one referenced Artifact metadata row is absent;
    * `:corrupt` — at least one referenced Artifact's recorded content
      digest or byte size cannot be verified;
    * `:unreadable` — at least one referenced Artifact's blob is unreadable
      for an OS reason.

  The metadata rows are returned unchanged in every case; integrity is a
  derived observation, not a mutation (P1-S02-T01-R15).
  """
  @spec fetch(map(), String.t()) :: fetch_outcome() | error_outcome()
  def fetch(%{conn: conn} = store, evidence_id)
      when is_binary(evidence_id) do
    with {:ok, evidence, artifact_ids} <- fetch_record(conn, evidence_id),
         {:ok, status} <- verify_artifact_set(store, artifact_ids) do
      {:ok, evidence, %{integrity_status: status}}
    end
  end

  # -- record pipeline --

  defp finalize_record({:ok, value}), do: value
  defp finalize_record({:error, %Error{} = error}), do: {:error, error}

  defp finalize_record({:error, reason}) do
    {:error,
     Error.new(
       :unknown,
       :transaction_failed,
       "the evidence recording transaction did not commit",
       %{reason: inspect(reason)}
     )}
  end

  defp classify_and_apply(tx, request) do
    case fetch_by_idempotency_key(tx, request.evidence.idempotency_key) do
      {:ok, existing} ->
        replay_or_conflict(existing, request.evidence)

      :none ->
        write_new(tx, request)
    end
  end

  defp replay_or_conflict(existing, candidate) do
    if existing.request_digest == candidate.request_digest do
      {:ok, existing, %{status: :replayed}}
    else
      {:error,
       Error.new(
         :idempotency_conflict,
         :key_reuse_different_request,
         "idempotency_key was reused with a different request",
         %{key: candidate.idempotency_key}
       )}
    end
  end

  defp write_new(tx, request) do
    with :ok <- maybe_admit(request),
         :ok <- verify_artifacts(tx, request.evidence.artifact_ids),
         :ok <- insert_evidence_record(tx, request.evidence),
         :ok <- insert_evidence_artifacts(tx, request.evidence),
         :ok <- insert_evidence_warnings(tx, request.evidence.evidence_id, request.warnings) do
      {:ok, request.evidence, %{status: :committed}}
    end
  end

  # Admission evaluation runs only for unseen keys. A supplied
  # admission_context must match every non-null request binding.
  defp maybe_admit(%RecordRequest{admission_context: nil}), do: :ok

  defp maybe_admit(%RecordRequest{evidence: evidence, admission_context: ctx}) do
    cond do
      ctx.current_subject_state_digest != evidence.subject_state_digest ->
        stale_error(:subject_state_digest)

      ctx.current_repository_state_digest != evidence.repository_state_digest ->
        stale_error(:repository_state_digest)

      Map.get(ctx, :current_patch_id, :__unset__) not in [:__unset__, evidence.patch_id] ->
        stale_error(:patch_id)

      Map.get(ctx, :current_patch_digest, :__unset__) not in [:__unset__, evidence.patch_digest] ->
        stale_error(:patch_digest)

      Map.get(ctx, :current_patch_result_digest, :__unset__) not in [
        :__unset__,
        evidence.patch_result_digest
      ] ->
        stale_error(:patch_result_digest)

      Map.get(ctx, :current_host_profile_digest, :__unset__) not in [
        :__unset__,
        evidence.host_profile_digest
      ] ->
        stale_error(:host_profile_digest)

      Map.get(ctx, :current_command_registration_digest, :__unset__) not in [
        :__unset__,
        evidence.command_registration_digest
      ] ->
        stale_error(:command_registration_digest)

      Map.get(ctx, :current_command_result_id, :__unset__) not in [
        :__unset__,
        evidence.command_result_id
      ] ->
        stale_error(:command_result_id)

      Map.get(ctx, :current_evaluator_digest, :__unset__) not in [
        :__unset__,
        evidence.evaluator_digest
      ] ->
        stale_error(:evaluator_digest)

      true ->
        :ok
    end
  end

  defp stale_error(field) do
    {:error,
     Error.new(
       :integrity,
       :stale,
       "admission_context binding does not match the proposed evidence record",
       %{field: field}
     )}
  end

  defp verify_artifacts(_tx, []), do: :ok

  defp verify_artifacts(tx, artifact_ids) do
    placeholders = Enum.map_join(1..length(artifact_ids), ",", &"?#{&1}")

    rows =
      Connection.query!(
        tx,
        "SELECT artifact_id FROM artifacts WHERE artifact_id IN (#{placeholders})",
        artifact_ids
      )

    found = MapSet.new(rows, fn [id] -> id end)

    case Enum.find(artifact_ids, fn id -> not MapSet.member?(found, id) end) do
      nil ->
        :ok

      missing_id ->
        {:error,
         Error.new(
           :integrity,
           :missing_artifact,
           "referenced artifact metadata is not present",
           %{artifact_id: missing_id}
         )}
    end
  end

  defp insert_evidence_record(tx, evidence) do
    Connection.query!(
      tx,
      """
      INSERT INTO evidence_records (
        evidence_id, session_id, run_id, criterion_id, criterion_revision,
        subject_id, subject_kind, subject_state_digest,
        producer_kind, producer_id,
        method, result, repository_state_digest,
        patch_id, patch_digest, patch_result_digest,
        host_profile_digest, command_registration_digest, command_result_id,
        evaluator_digest, observation_digest,
        completeness, freshness_rule,
        observed_at, recorded_at, rationale,
        evidence_schema, idempotency_key, request_digest, record_digest
      ) VALUES (
        ?1, ?2, ?3, ?4, ?5,
        ?6, ?7, ?8,
        ?9, ?10,
        ?11, ?12, ?13,
        ?14, ?15, ?16,
        ?17, ?18, ?19,
        ?20, ?21,
        ?22, ?23,
        ?24, ?25, ?26,
        ?27, ?28, ?29, ?30
      )
      """,
      [
        evidence.evidence_id,
        evidence.session_id,
        evidence.run_id,
        evidence.criterion_id,
        evidence.criterion_revision,
        evidence.subject_id,
        to_string(evidence.subject_kind),
        evidence.subject_state_digest,
        to_string(evidence.producer_kind),
        evidence.producer_id,
        to_string(evidence.method),
        to_string(evidence.result),
        evidence.repository_state_digest,
        evidence.patch_id,
        evidence.patch_digest,
        evidence.patch_result_digest,
        evidence.host_profile_digest,
        evidence.command_registration_digest,
        evidence.command_result_id,
        evidence.evaluator_digest,
        evidence.observation_digest,
        to_string(evidence.completeness),
        to_string(evidence.freshness_rule),
        evidence.observed_at,
        evidence.recorded_at,
        evidence.rationale,
        evidence.schema,
        evidence.idempotency_key,
        evidence.request_digest,
        evidence.record_digest
      ]
    )

    :ok
  end

  defp insert_evidence_artifacts(tx, evidence) do
    artifact_ids = evidence.artifact_ids |> Enum.with_index()

    Enum.reduce_while(artifact_ids, :ok, fn {artifact_id, position}, acc ->
      case acc do
        :ok ->
          Connection.query!(
            tx,
            """
            INSERT INTO evidence_artifacts (evidence_id, artifact_id, position)
            VALUES (?1, ?2, ?3)
            """,
            [evidence.evidence_id, artifact_id, position]
          )

          {:cont, :ok}

        _ ->
          {:halt, acc}
      end
    end)
  end

  defp insert_evidence_warnings(tx, evidence_id, warnings) do
    warnings_with_position = Enum.with_index(warnings)

    Enum.reduce_while(warnings_with_position, :ok, fn {warning, position}, acc ->
      case acc do
        :ok ->
          Connection.query!(
            tx,
            """
            INSERT INTO evidence_warnings (evidence_id, position, warning)
            VALUES (?1, ?2, ?3)
            """,
            [evidence_id, position, warning]
          )

          {:cont, :ok}

        _ ->
          {:halt, acc}
      end
    end)
  end

  # -- fetch pipeline --

  defp fetch_record(conn, evidence_id) do
    rows =
      Connection.query!(
        conn,
        """
        SELECT evidence_id, session_id, run_id, criterion_id, criterion_revision,
               subject_id, subject_kind, subject_state_digest,
               producer_kind, producer_id,
               method, result, repository_state_digest,
               patch_id, patch_digest, patch_result_digest,
               host_profile_digest, command_registration_digest, command_result_id,
               evaluator_digest, observation_digest,
               completeness, freshness_rule,
               observed_at, recorded_at, rationale,
               evidence_schema, idempotency_key, request_digest, record_digest
        FROM evidence_records
        WHERE evidence_id = ?1
        """,
        [evidence_id]
      )

    case rows do
      [] ->
        {:error,
         Error.new(:precondition, :unknown_evidence, "evidence_id is not present", %{
           evidence_id: evidence_id
         })}

      [row] ->
        artifact_ids = fetch_artifact_ids(conn, evidence_id)
        {:ok, row_to_evidence(row, artifact_ids), artifact_ids}
    end
  end

  defp fetch_artifact_ids(conn, evidence_id) do
    rows =
      Connection.query!(
        conn,
        """
        SELECT artifact_id FROM evidence_artifacts
        WHERE evidence_id = ?1
        ORDER BY position ASC
        """,
        [evidence_id]
      )

    Enum.map(rows, fn [id] -> id end)
  end

  # Derive integrity status from the artifacts table alone; the blob rehash
  # check belongs to `Kiln.Artifact.Store.fetch/2` and is reused by callers.
  # A row-level absence marks :missing; a presence with mismatched content
  # digest or byte size marks :corrupt.
  defp verify_artifact_set(%{conn: conn}, artifact_ids) do
    case artifact_ids do
      [] ->
        {:ok, :verified}

      ids ->
        placeholders = Enum.map_join(1..length(ids), ",", &"?#{&1}")

        rows =
          Connection.query!(
            conn,
            "SELECT artifact_id FROM artifacts WHERE artifact_id IN (#{placeholders})",
            ids
          )

        found = MapSet.new(rows, fn [id] -> id end)

        case Enum.find(ids, &(not MapSet.member?(found, &1))) do
          nil -> {:ok, :verified}
          _missing -> {:ok, :missing}
        end
    end
  end

  defp fetch_by_idempotency_key(tx, key) do
    rows =
      Connection.query!(
        tx,
        """
        SELECT evidence_id, session_id, run_id, criterion_id, criterion_revision,
               subject_id, subject_kind, subject_state_digest,
               producer_kind, producer_id,
               method, result, repository_state_digest,
               patch_id, patch_digest, patch_result_digest,
               host_profile_digest, command_registration_digest, command_result_id,
               evaluator_digest, observation_digest,
               completeness, freshness_rule,
               observed_at, recorded_at, rationale,
               evidence_schema, idempotency_key, request_digest, record_digest
        FROM evidence_records
        WHERE idempotency_key = ?1
        """,
        [key]
      )

    case rows do
      [] -> :none
      [row] -> {:ok, row_to_evidence(row, [])}
    end
  end

  defp row_to_evidence(row, artifact_ids) do
    [
      evidence_id,
      session_id,
      run_id,
      criterion_id,
      criterion_revision,
      subject_id,
      subject_kind,
      subject_state_digest,
      producer_kind,
      producer_id,
      method,
      result,
      repository_state_digest,
      patch_id,
      patch_digest,
      patch_result_digest,
      host_profile_digest,
      command_registration_digest,
      command_result_id,
      evaluator_digest,
      observation_digest,
      completeness,
      freshness_rule,
      observed_at,
      recorded_at,
      rationale,
      schema,
      idempotency_key,
      request_digest,
      record_digest
    ] = row

    %Evidence{
      evidence_id: evidence_id,
      session_id: session_id,
      run_id: run_id,
      criterion_id: criterion_id,
      criterion_revision: criterion_revision,
      subject_id: subject_id,
      subject_kind: subject_kind_atom(subject_kind),
      subject_state_digest: subject_state_digest,
      producer_kind: producer_kind_atom(producer_kind),
      producer_id: producer_id,
      method: method_atom(method),
      result: result_atom(result),
      repository_state_digest: repository_state_digest,
      artifact_ids: artifact_ids,
      patch_id: patch_id,
      patch_digest: patch_digest,
      patch_result_digest: patch_result_digest,
      host_profile_digest: host_profile_digest,
      command_registration_digest: command_registration_digest,
      command_result_id: command_result_id,
      evaluator_digest: evaluator_digest,
      observation_digest: observation_digest,
      completeness: completeness_atom(completeness),
      freshness_rule: freshness_rule_atom(freshness_rule),
      observed_at: observed_at,
      recorded_at: recorded_at,
      rationale: rationale,
      schema: schema,
      idempotency_key: idempotency_key,
      request_digest: request_digest,
      record_digest: record_digest
    }
  end

  defp result_atom("pass"), do: :pass
  defp result_atom("fail"), do: :fail
  defp result_atom("blocked"), do: :blocked
  defp result_atom("unknown"), do: :unknown

  defp method_atom("registered_command"), do: :registered_command
  defp method_atom("repository_observation"), do: :repository_observation
  defp method_atom("deterministic_validator"), do: :deterministic_validator
  defp method_atom("user_observation"), do: :user_observation

  defp subject_kind_atom(v) do
    case v do
      "session" -> :session
      "run" -> :run
      "operation" -> :operation
      "patch" -> :patch
      "command" -> :command
      "artifact" -> :artifact
      "evidence" -> :evidence
      "repository" -> :repository
    end
  end

  defp producer_kind_atom(v) do
    case v do
      "command" -> :command
      "provider" -> :provider
      "pack" -> :pack
      "patch" -> :patch
      "repository" -> :repository
      "user" -> :user
      "deterministic_service" -> :deterministic_service
    end
  end

  defp completeness_atom(v) do
    case v do
      "complete" -> :complete
      "partial" -> :partial
      "truncated" -> :truncated
      "missing" -> :missing
      "unknown" -> :unknown
    end
  end

  defp freshness_rule_atom(v) do
    case v do
      "same_repository_state" ->
        :same_repository_state

      "same_patch_and_repository_state" ->
        :same_patch_and_repository_state

      "same_command_registration_and_repository_state" ->
        :same_command_registration_and_repository_state

      "manual_same_repository_state" ->
        :manual_same_repository_state
    end
  end
end
