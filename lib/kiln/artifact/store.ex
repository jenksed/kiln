defmodule Kiln.Artifact.Store do
  @moduledoc """
  Durable Artifact byte store and metadata persistence (P1-S02-T01-R01..R04, R13).

  ## Public surface

    * `put/2` — publish an Artifact by request and return the committed record.
    * `fetch/2` — reopen, verify, and return the persisted record.

  No `put/3` is exported. The Store is the sole authority for Artifact
  publication; this module owns one outer `BEGIN IMMEDIATE` metadata
  transaction and the staged, fsync'd, digest-verified, atomic same-directory
  rename required by the accepted contract. It never opens a nested
  transaction, never invokes another write API, and never accepts a caller
  callback as transaction logic (P1-S02-T01-R06, R13).

  ## Publication sequence

  1. Validate the request envelope (`Kiln.Artifact.PutRequest`).
  2. Compute the SHA-256 content digest and canonical request digest.
  3. Open one `BEGIN IMMEDIATE` transaction and classify the idempotency key.
  4. Return an integrity-verified replay, or reject a conflict, before any new
     blob write.
  5. For an unseen key, write bytes to a same-directory temporary file, sync,
     close, reopen, and verify size and digest.
  6. Atomically rename into the content-addressed final path; if the final
     path already holds an identical blob, verify it and proceed; a
     non-identical existing blob returns `:integrity`.
  7. Insert exactly one Artifact metadata row and commit only after the final
     blob is reverified.

  A crash after content promotion but before metadata commit may leave only an
  unreachable digest-addressed blob. That blob creates no Artifact identity
  and grants no authority; a later matching write may reuse it
  (P1-S02-T01-A03).
  """

  alias Kiln.Artifact
  alias Kiln.Artifact.{FS, PutRequest}
  alias Kiln.Store.{Connection, Error}

  @type integrity_status :: :verified | :corrupt | :missing | :unreadable

  @type put_outcome :: {:ok, Artifact.t(), %{status: :committed | :replayed}}
  @type fetch_outcome :: {:ok, Artifact.t(), %{integrity_status: integrity_status()}}
  @type error_outcome :: {:error, Error.t()}

  @doc """
  Publish an Artifact.

  Accepts exactly `(ready_store, %PutRequest{})`. The returned tuple carries
  `status: :committed` for an unseen key or `status: :replayed` for an exact
  idempotency retry. Conflicting reuse of an idempotency key returns
  `:idempotency_conflict` and writes nothing. A failed publication never
  leaves a partial Artifact row or an orphaned committed blob.
  """
  @spec put(map(), PutRequest.t()) :: put_outcome() | error_outcome()
  def put(%{conn: conn, artifact_root: root} = _store, %PutRequest{} = request) do
    case prepare_publication(root, request) do
      {:ok, content_digest, location, artifact} ->
        commit_publication(conn, root, request, artifact, content_digest, location)

      {:error, %Error{} = error} ->
        {:error, error}
    end
  end

  defp prepare_publication(root, request) do
    with :ok <- verify_root(root),
         {:ok, content_digest} <- compute_content_digest(request),
         {:ok, location} <- derive_location(content_digest),
         {:ok, candidate} <- build_candidate(request, content_digest, location),
         {:ok, artifact} <- Artifact.new(candidate),
         {:ok, artifact_with_digest} <- attach_request_digest(artifact) do
      {:ok, content_digest, location, artifact_with_digest}
    end
  end

  @doc """
  Fetch and integrity-check a previously committed Artifact.

  Returns the persisted record with a derived `integrity_status`:

    * `:verified` — the blob at the recorded content path matches the stored
      content digest and byte size;
    * `:corrupt` — the blob is present but mismatched;
    * `:missing` — the blob is absent;
    * `:unreadable` — the blob is unreadable for an OS reason.

  The metadata row is returned unchanged in every case; integrity is a
  derived observation, not a mutation (P1-S02-T01-R15).
  """
  @spec fetch(map(), String.t()) :: fetch_outcome() | error_outcome()
  def fetch(%{conn: conn, artifact_root: root} = _store, artifact_id)
      when is_binary(artifact_id) do
    case fetch_row(conn, artifact_id) do
      {:ok, artifact} ->
        verify_and_return(root, artifact)

      {:error, %Error{} = error} ->
        {:error, error}
    end
  end

  # -- publication pipeline --

  defp verify_root(root) do
    case FS.ensure_root(root) do
      :ok -> :ok
      {:error, %Error{class: :integrity} = error} -> {:error, error}
    end
  end

  defp compute_content_digest(%PutRequest{bytes: bytes}) do
    digest = bytes |> (&:crypto.hash(:sha256, &1)).() |> Base.encode16(case: :lower)
    {:ok, "sha256:" <> digest}
  end

  defp derive_location(digest), do: {:ok, FS.content_location(digest)}

  defp build_candidate(request, content_digest, location) do
    metadata =
      Map.merge(request.metadata, %{
        artifact_id: request.artifact_id,
        idempotency_key: request.idempotency_key,
        recorded_at: request.recorded_at,
        content_digest: content_digest,
        byte_size: byte_size(request.bytes),
        content_location: location
      })

    {:ok, metadata}
  end

  defp attach_request_digest(%Artifact{} = artifact) do
    {:ok, %{artifact | request_digest: Artifact.request_digest(artifact)}}
  end

  defp commit_publication(
         conn,
         root,
         request,
         artifact,
         content_digest,
         location
       ) do
    {stage_path, final_path} = FS.stage_pair(root, location, request.idempotency_key)

    try do
      result =
        Connection.transaction(conn, fn tx ->
          classify_and_apply(
            tx,
            root,
            request,
            artifact,
            content_digest,
            location,
            stage_path,
            final_path
          )
        end)

      case result do
        {:ok, value} ->
          value

        {:error, %Error{class: :integrity} = error} ->
          FS.cleanup_stage(stage_path)
          {:error, error}

        {:error, %Error{class: :idempotency_conflict} = error} ->
          FS.cleanup_stage(stage_path)
          {:error, error}

        {:error, %Error{class: :io} = error} ->
          FS.cleanup_stage(stage_path)
          {:error, error}

        {:error, reason} ->
          FS.cleanup_stage(stage_path)

          {:error,
           Error.new(
             :unknown,
             :transaction_failed,
             "the artifact publication transaction did not commit",
             %{reason: inspect(reason)}
           )}
      end
    rescue
      e in [ErlangError] ->
        FS.cleanup_stage(stage_path)
        {:error, fs_fault_error(e)}
    catch
      kind, reason ->
        FS.cleanup_stage(stage_path)

        {:error,
         Error.new(
           :unknown,
           :transaction_threw,
           "the artifact publication raised during a fault",
           %{kind: kind, reason: inspect(reason)}
         )}
    end
  end

  defp fs_fault_error(reason) do
    case reason do
      {:kiln_fs_fault, key, _} ->
        Error.new(
          :unknown,
          :fs_fault,
          "the artifact publication tripped a test-only filesystem fault",
          %{boundary: key}
        )

      other ->
        Error.new(
          :unknown,
          :fs_fault,
          "the artifact publication tripped a test-only filesystem fault",
          %{reason: inspect(other)}
        )
    end
  end

  defp classify_and_apply(
         tx,
         root,
         request,
         artifact,
         content_digest,
         location,
         stage_path,
         final_path
       ) do
    case fetch_by_idempotency_key(tx, request.idempotency_key) do
      {:ok, existing} ->
        replay_or_conflict(existing, artifact, root, content_digest)

      :none ->
        write_new(tx, root, request, artifact, content_digest, location, stage_path, final_path)
    end
  end

  # Replay only when the stored row's canonical request digest matches the
  # caller's. A mismatch is a structured integrity-classified rejection; the
  # transaction rolls back and writes nothing (P1-S02-T01-R11).
  defp replay_or_conflict(existing, candidate, root, content_digest) do
    if existing.request_digest == candidate.request_digest do
      verify_blob_or_fail(root, existing, content_digest, :replayed)
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

  defp verify_blob_or_fail(root, artifact, content_digest, status) do
    case verify_blob(root, artifact) do
      {:ok, %{digest: ^content_digest, size: size}} when size == artifact.byte_size ->
        {:ok, artifact, %{status: status}}

      {:ok, %{digest: ^content_digest}} ->
        {:error,
         Error.new(
           :integrity,
           :artifact_size_mismatch,
           "stored blob digest matches but size differs",
           %{}
         )}

      {:ok, _} ->
        {:error,
         Error.new(
           :integrity,
           :artifact_corrupt,
           "stored blob does not match metadata",
           %{}
         )}

      {:error, %Error{class: :integrity} = error} ->
        {:error, error}
    end
  end

  defp write_new(
         tx,
         root,
         request,
         artifact,
         content_digest,
         location,
         stage_path,
         final_path
       ) do
    with :ok <- FS.verify_chain(root, location),
         :ok <- stage_publish(root, request, content_digest, stage_path, final_path),
         :ok <- maybe_inject_metadata_persist() do
      Connection.query!(
        tx,
        """
        INSERT INTO artifacts (
          artifact_id, session_id, run_id, creator_operation_id,
          owner_kind, owner_id, producer_kind, producer_id,
          kind, media_type, encoding,
          content_digest, byte_size, content_location,
          repository_state_digest, host_profile_digest,
          trust, sensitivity, retention_class, completeness,
          recorded_at, artifact_schema, idempotency_key, request_digest
        ) VALUES (
          ?1, ?2, ?3, ?4,
          ?5, ?6, ?7, ?8,
          ?9, ?10, ?11,
          ?12, ?13, ?14,
          ?15, ?16,
          ?17, ?18, ?19, ?20,
          ?21, ?22, ?23, ?24
        )
        """,
        [
          artifact.artifact_id,
          artifact.session_id,
          artifact.run_id,
          artifact.creator_operation_id,
          artifact.owner_kind,
          artifact.owner_id,
          artifact.producer_kind,
          artifact.producer_id,
          artifact.kind,
          artifact.media_type,
          artifact.encoding,
          artifact.content_digest,
          artifact.byte_size,
          artifact.content_location,
          artifact.repository_state_digest,
          artifact.host_profile_digest,
          artifact.trust,
          artifact.sensitivity,
          artifact.retention_class,
          artifact.completeness,
          artifact.recorded_at,
          artifact.schema,
          artifact.idempotency_key,
          artifact.request_digest
        ]
      )

      {:ok, artifact, %{status: :committed}}
    end
  end

  # Stage the bytes, fsync, verify, and atomic-rename. A failure at any step
  # raises back into the transaction rollback and returns a typed error.
  defp stage_publish(root, request, content_digest, stage_path, final_path) do
    expected_size = byte_size(request.bytes)

    with :ok <- FS.stage_write(stage_path, request.bytes),
         {:ok, %{size: ^expected_size, digest: staged_digest}} <-
           FS.verify_staged(stage_path, expected_size, content_digest),
         :ok <- ensure_digest(staged_digest, content_digest),
         :ok <- ensure_target(root, request, content_digest, final_path),
         :ok <- FS.publish(stage_path, final_path) do
      :ok
    end
  end

  # Test seam: a deterministic failure mechanism at the narrow boundary between
  # content promotion and Artifact metadata commit. Tests set
  # `Application.put_env(:kiln, :store_fault, %{metadata_persist: :raise})`
  # to simulate a fault after the blob has been renamed but before the SQL
  # INSERT succeeds. The Store layer translates the ErlangError into a typed
  # `unknown` error; the transaction rolls back, no row is committed, and the
  # promoted blob remains as a permitted pre-metadata orphan (AC03).
  defp maybe_inject_metadata_persist do
    case Application.get_env(:kiln, :store_fault, %{}) |> Map.get(:metadata_persist) do
      :raise -> :erlang.error({:kiln_store_fault, :metadata_persist, []})
      _ -> :ok
    end
  end

  defp ensure_digest(actual, expected) when actual == expected, do: :ok

  defp ensure_digest(actual, expected) do
    {:error,
     Error.new(:integrity, :artifact_digest_mismatch, "staged digest does not match request", %{
       expected: expected,
       actual: actual
     })}
  end

  # If the final destination already holds a blob, the bytes must match the
  # digest we are about to publish; otherwise the destination is corrupt or
  # the request is malformed. Identical blobs are accepted and the existing
  # file is reused (P1-S02-T01-A03, R04).
  #
  # Classifies the leaf via lstat before opening so a symlink at the final
  # component is rejected as :integrity without dereferencing its target.
  defp ensure_target(_root, request, content_digest, final_path) do
    case FS.classify_leaf(final_path) do
      {:ok, :absent} ->
        :ok

      {:ok, :regular} ->
        case FS.rehash_existing(final_path) do
          {:ok, %{digest: ^content_digest, size: size}} when size == byte_size(request.bytes) ->
            :ok

          {:ok, %{digest: ^content_digest}} ->
            {:error,
             Error.new(:integrity, :artifact_size_mismatch, "destination size differs", %{})}

          {:ok, _} ->
            {:error,
             Error.new(
               :integrity,
               :destination_conflict,
               "destination already holds a non-identical blob",
               %{}
             )}

          {:error, %Error{class: :integrity} = error} ->
            {:error, error}
        end

      {:ok, :symlink} ->
        {:error,
         Error.new(
           :integrity,
           :leaf_is_symlink,
           "destination is a symlink",
           %{}
         )}

      {:ok, :directory} ->
        {:error,
         Error.new(
           :integrity,
           :leaf_is_directory,
           "destination is a directory",
           %{}
         )}

      {:ok, {:special, type}} ->
        {:error,
         Error.new(
           :integrity,
           :leaf_is_special_file,
           "destination is a special file",
           %{type: type}
         )}

      {:error, %Error{} = err} ->
        {:error, err}
    end
  end

  defp verify_and_return(root, artifact) do
    case verify_blob(root, artifact) do
      {:ok, %{digest: digest, size: size}}
      when digest == artifact.content_digest and size == artifact.byte_size ->
        {:ok, artifact, %{integrity_status: :verified}}

      {:ok, %{digest: digest, size: size}}
      when digest == artifact.content_digest and size != artifact.byte_size ->
        {:ok, artifact, %{integrity_status: :corrupt}}

      {:ok, _} ->
        {:ok, artifact, %{integrity_status: :corrupt}}

      {:error, %Error{code: :artifact_missing}} ->
        {:ok, artifact, %{integrity_status: :missing}}

      {:error, %Error{class: :integrity}} ->
        {:ok, artifact, %{integrity_status: :corrupt}}

      {:error, %Error{class: :io}} ->
        {:ok, artifact, %{integrity_status: :unreadable}}

      {:error, %Error{} = error} ->
        {:error, error}
    end
  end

  defp verify_blob(root, artifact) do
    final_path = FS.final_path(root, artifact.content_location)
    FS.rehash_existing(final_path)
  end

  # -- persistence helpers --

  defp fetch_by_idempotency_key(tx, key) do
    rows =
      Connection.query!(
        tx,
        """
        SELECT artifact_id, session_id, run_id, creator_operation_id,
               owner_kind, owner_id, producer_kind, producer_id,
               kind, media_type, encoding,
               content_digest, byte_size, content_location,
               repository_state_digest, host_profile_digest,
               trust, sensitivity, retention_class, completeness,
               recorded_at, artifact_schema, idempotency_key, request_digest
        FROM artifacts
        WHERE idempotency_key = ?1
        """,
        [key]
      )

    case rows do
      [] ->
        :none

      [row] ->
        {:ok, row_to_artifact(row)}
    end
  end

  defp fetch_row(conn, artifact_id) do
    rows =
      Connection.query!(
        conn,
        """
        SELECT artifact_id, session_id, run_id, creator_operation_id,
               owner_kind, owner_id, producer_kind, producer_id,
               kind, media_type, encoding,
               content_digest, byte_size, content_location,
               repository_state_digest, host_profile_digest,
               trust, sensitivity, retention_class, completeness,
               recorded_at, artifact_schema, idempotency_key, request_digest
        FROM artifacts
        WHERE artifact_id = ?1
        """,
        [artifact_id]
      )

    case rows do
      [] ->
        {:error,
         Error.new(:precondition, :unknown_artifact, "artifact_id is not present", %{
           artifact_id: artifact_id
         })}

      [row] ->
        {:ok, row_to_artifact(row)}
    end
  end

  defp row_to_artifact(row) do
    [
      artifact_id,
      session_id,
      run_id,
      creator_operation_id,
      owner_kind,
      owner_id,
      producer_kind,
      producer_id,
      kind,
      media_type,
      encoding,
      content_digest,
      byte_size,
      content_location,
      repository_state_digest,
      host_profile_digest,
      trust,
      sensitivity,
      retention_class,
      completeness,
      recorded_at,
      schema,
      idempotency_key,
      request_digest
    ] = row

    %Artifact{
      artifact_id: artifact_id,
      session_id: session_id,
      run_id: run_id,
      creator_operation_id: creator_operation_id,
      owner_kind: owner_kind,
      owner_id: owner_id,
      producer_kind: producer_kind,
      producer_id: producer_id,
      kind: kind,
      media_type: media_type,
      encoding: encoding,
      content_digest: content_digest,
      byte_size: byte_size,
      content_location: content_location,
      repository_state_digest: repository_state_digest,
      host_profile_digest: host_profile_digest,
      trust: trust,
      sensitivity: sensitivity,
      retention_class: retention_class,
      completeness: completeness,
      recorded_at: recorded_at,
      schema: schema,
      idempotency_key: idempotency_key,
      request_digest: request_digest
    }
  end
end
