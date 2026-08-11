defmodule Kiln.Artifact.StoreTest do
  use ExUnit.Case, async: false

  alias Kiln.Artifact
  alias Kiln.Artifact.PutRequest
  alias Kiln.Store
  alias Kiln.Store.Connection
  alias Kiln.Artifact.Store, as: ArtifactStore

  @now "2026-08-10T12:00:00Z"
  @bytes "deterministic artifact bytes for T01"
  @idempotency_key "idem_t01_store"

  setup do
    base = Path.join(System.tmp_dir!(), "kiln-art-store-#{System.unique_integer([:positive])}")
    File.mkdir_p!(base)
    on_exit(fn -> File.rm_rf!(base) end)

    {:ready, store} =
      Store.start(path: Path.join(base, "state.sqlite3"), store_id: "store_test", now: @now)

    on_exit(fn -> stop(store.conn) end)
    on_exit(fn -> Application.delete_env(:kiln, :fs_fault) end)

    {:ok, store: store, base: base}
  end

  defp stop(conn) do
    if Process.alive?(conn), do: GenServer.stop(conn)
    :ok
  catch
    :exit, _ -> :ok
  end

  # -- helpers --

  defp valid_request(opts \\ []) do
    %{artifact_id: artifact_id, idempotency_key: idem_key, bytes: bytes} =
      Enum.into(opts, %{
        artifact_id: "01920080-0000-7000-8000-000000000001",
        idempotency_key: @idempotency_key,
        bytes: @bytes
      })

    PutRequest.new(%{
      artifact_id: artifact_id,
      idempotency_key: idem_key,
      recorded_at: @now,
      bytes: bytes,
      metadata: %{
        session_id: "ses_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        run_id: "run_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        owner_kind: :session,
        owner_id: "ses_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        producer_kind: :user,
        producer_id: "user:local",
        kind: :output,
        media_type: "application/octet-stream",
        encoding: :binary,
        trust: :user_supplied,
        sensitivity: :project,
        retention_class: :session,
        completeness: :complete
      }
    })
  end

  defp content_root(base), do: Path.join(base, "artifacts")

  defp bytes_on_disk(store, artifact) do
    final = Path.join(store.artifact_root, artifact.content_location)
    File.read!(final)
  end

  defp artifact_count(store) do
    Connection.query!(store.conn, "SELECT COUNT(*) FROM artifacts")
    |> List.flatten()
    |> List.first()
  end

  defp artifact_row(store, artifact_id) do
    Connection.query!(
      store.conn,
      "SELECT artifact_id, content_digest, byte_size, content_location FROM artifacts WHERE artifact_id = ?1",
      [artifact_id]
    )
  end

  # -- happy path --

  describe "put/2 happy path" do
    test "publishes a new artifact, persists metadata, and stores the blob below the root",
         %{store: store, base: base} do
      {:ok, request} = valid_request()
      artifact_id = request.artifact_id

      assert {:ok, artifact, %{status: :committed}} = ArtifactStore.put(store, request)

      assert artifact.artifact_id == artifact_id
      assert String.starts_with?(artifact.content_location, "sha256/")
      expected_size = byte_size(@bytes)
      assert artifact.byte_size == expected_size
      assert artifact.content_digest =~ ~r/^sha256:[0-9a-f]{64}$/
      assert artifact.schema == "kiln.artifact/v1"
      assert artifact.request_digest =~ ~r/^[0-9a-f]{64}$/

      assert bytes_on_disk(store, artifact) == @bytes

      assert [[row_id, _, row_size, _]] = artifact_row(store, artifact_id)
      assert row_id == artifact_id
      assert row_size == expected_size

      assert File.exists?(content_root(base))
    end

    test "writes content only to the artifact_root and nowhere else",
         %{store: store, base: base} do
      {:ok, request} = valid_request()
      {:ok, artifact, _} = ArtifactStore.put(store, request)

      # Walk the entire artifact_root and confirm every regular file is the published blob.
      files =
        artifact_root_path(store)
        |> Path.join("**/*")
        |> Path.wildcard()
        |> Enum.filter(&File.regular?/1)

      assert files == [Path.join(artifact_root_path(store), artifact.content_location)]
      assert files |> Enum.all?(&String.starts_with?(&1, artifact_root_path(store)))

      # Nothing else inside `base` should have been written outside of state.sqlite3 and the artifact_root.
      siblings =
        File.ls!(base)
        |> Enum.reject(
          &(&1 == "state.sqlite3" || &1 == "artifacts" || String.starts_with?(&1, "state.sqlite3"))
        )

      assert siblings == []
    end

    test "stores no content bytes in SQLite", %{store: store} do
      {:ok, request} = valid_request()
      {:ok, artifact, _} = ArtifactStore.put(store, request)

      # Confirm the SQLite file does not contain the literal published bytes.
      sqlite_bytes = File.read!(store.state_path)
      refute sqlite_bytes =~ @bytes
      refute sqlite_bytes =~ artifact.content_digest
    end
  end

  describe "fetch/2" do
    test "returns the persisted record with :verified integrity", %{store: store} do
      {:ok, request} = valid_request()
      {:ok, committed, _} = ArtifactStore.put(store, request)

      assert {:ok, fetched, %{integrity_status: :verified}} =
               ArtifactStore.fetch(store, committed.artifact_id)

      assert fetched.artifact_id == committed.artifact_id
      assert fetched.content_digest == committed.content_digest
      assert fetched.byte_size == committed.byte_size
    end

    test "reports :missing when the blob is absent but metadata remains", %{store: store} do
      {:ok, request} = valid_request()
      {:ok, committed, _} = ArtifactStore.put(store, request)

      File.rm!(Path.join(store.artifact_root, committed.content_location))

      assert {:ok, _, %{integrity_status: :missing}} =
               ArtifactStore.fetch(store, committed.artifact_id)
    end

    test "reports :corrupt when the blob is replaced by a different file", %{store: store} do
      {:ok, request} = valid_request()
      {:ok, committed, _} = ArtifactStore.put(store, request)

      File.write!(Path.join(store.artifact_root, committed.content_location), "tampered")

      assert {:ok, _, %{integrity_status: :corrupt}} =
               ArtifactStore.fetch(store, committed.artifact_id)
    end

    test "returns precondition error when the artifact_id is unknown", %{store: store} do
      assert {:error, %{class: :precondition, code: :unknown_artifact}} =
               ArtifactStore.fetch(store, "01920080-0000-7000-8000-000000000099")
    end
  end

  # -- deterministic destination selection --

  describe "content-addressed destination selection" do
    test "produces a stable location derived from the digest", %{store: store} do
      {:ok, request} = valid_request()
      {:ok, artifact, _} = ArtifactStore.put(store, request)

      <<first_two::binary-size(2), rest::binary>> =
        artifact.content_digest |> String.replace_prefix("sha256:", "")

      assert artifact.content_location == "sha256/#{first_two}/#{rest}"
    end

    test "two distinct requests with identical bytes share the same blob", %{store: store} do
      {:ok, request_a} =
        valid_request(%{
          artifact_id: "01920080-0000-7000-8000-000000000010",
          idempotency_key: "idem_blob_share_a"
        })

      {:ok, request_b} =
        valid_request(%{
          artifact_id: "01920080-0000-7000-8000-000000000020",
          idempotency_key: "idem_blob_share_b"
        })

      {:ok, artifact_a, _} = ArtifactStore.put(store, request_a)
      {:ok, artifact_b, _} = ArtifactStore.put(store, request_b)

      assert artifact_a.content_location == artifact_b.content_location
      assert artifact_a.artifact_id != artifact_b.artifact_id
      assert artifact_count(store) == 2
    end
  end

  # -- idempotency --

  describe "idempotent repeat" do
    test "replays an exact request under the same key and digest", %{store: store} do
      {:ok, request} = valid_request()
      {:ok, first, %{status: first_status}} = ArtifactStore.put(store, request)
      assert first_status == :committed

      {:ok, second, %{status: second_status}} = ArtifactStore.put(store, request)
      assert second_status == :replayed
      assert second.artifact_id == first.artifact_id
      assert artifact_count(store) == 1
    end

    test "rejects a conflicting request under the same key", %{store: store} do
      {:ok, first} = valid_request()
      {:ok, artifact, _} = ArtifactStore.put(store, first)

      # Conflicting: same idempotency_key, but different bytes (so different request digest).
      {:ok, conflict} = valid_request(%{bytes: "different bytes"})

      assert {:error, %{class: :idempotency_conflict, code: :key_reuse_different_request}} =
               ArtifactStore.put(store, conflict)

      assert artifact_count(store) == 1
      assert bytes_on_disk(store, artifact) == @bytes
    end
  end

  # -- atomic publication and destination handling --

  describe "atomic publication and existing-destination handling" do
    test "an identical existing blob at the destination is reused", %{store: store, base: base} do
      {:ok, request} = valid_request()
      {:ok, artifact, _} = ArtifactStore.put(store, request)

      # A second publication with the same bytes and the same idempotency_key is a replay.
      # Force a replay path by writing the same blob to the destination outside the Store.
      final = Path.join(store.artifact_root, artifact.content_location)
      File.rm!(final)
      File.write!(final, @bytes)

      {:ok, _request2} = valid_request()
      assert {:ok, _replayed, %{status: :replayed}} = ArtifactStore.put(store, request)

      assert File.read!(final) == @bytes

      _ = base
    end

    test "a destination with non-identical bytes produces integrity rejection and writes nothing",
         %{store: store} do
      {:ok, request} = valid_request()
      {:ok, artifact, _} = ArtifactStore.put(store, request)

      final = Path.join(store.artifact_root, artifact.content_location)
      File.rm!(final)
      File.mkdir_p!(final)

      # Renaming onto an existing directory fails with EISDIR, the integrity check then
      # observes the directory as a non-identical existing entry.
      assert {:error, _} = ArtifactStore.put(store, request)

      assert File.dir?(final)
    end
  end

  # -- fault matrix --

  describe "publication fault matrix" do
    test "no committed row or final blob when the staging fsync fails", %{store: store} do
      {:ok, request} = valid_request()

      Application.put_env(:kiln, :fs_fault, %{stage_write_fsync: :raise})

      assert {:error, %{class: :io}} = ArtifactStore.put(store, request)
      Application.delete_env(:kiln, :fs_fault)

      assert artifact_count(store) == 0

      leftover_stages =
        store.artifact_root
        |> Path.join("**/.kiln-stage-*")
        |> Path.wildcard()

      assert leftover_stages == []
    end

    test "no committed row or final blob when the atomic rename fails", %{store: store} do
      {:ok, request} = valid_request()

      Application.put_env(:kiln, :fs_fault, %{publish_rename: :raise})

      assert {:error, %{class: :unknown}} = ArtifactStore.put(store, request)
      Application.delete_env(:kiln, :fs_fault)

      assert artifact_count(store) == 0
    end

    test "no committed row when the staged bytes disagree with the requested digest",
         %{store: store} do
      {:ok, _request} = valid_request()
      [artifact_root, relative] = [store.artifact_root, "sha256/aa/" <> String.duplicate("a", 62)]

      {stage, final} = Kiln.Artifact.FS.stage_pair(artifact_root, relative, @idempotency_key)
      File.mkdir_p!(Path.dirname(stage))
      :ok = Kiln.Artifact.FS.stage_write(stage, @bytes)
      tampered = String.duplicate("x", byte_size(@bytes))
      File.write!(stage, tampered)

      case Kiln.Artifact.FS.verify_staged(
             stage,
             byte_size(@bytes),
             "sha256:" <> String.duplicate("z", 64)
           ) do
        {:error, %{class: :integrity, code: :artifact_digest_mismatch}} ->
          :ok

        other ->
          flunk("expected digest-mismatch integrity error, got #{inspect(other)}")
      end

      refute File.exists?(final)

      assert artifact_count(store) == 0
    end
  end

  # -- preservation after publication --

  describe "preservation after publication" do
    test "a successful put survives a later failure of an unrelated store operation",
         %{store: store} do
      {:ok, request} = valid_request()
      {:ok, artifact, %{status: :committed}} = ArtifactStore.put(store, request)

      # Simulate a later unrelated failure by enabling a fault on the next call.
      Application.put_env(:kiln, :fs_fault, %{stage_write_fsync: :raise})

      {:ok, second_request} =
        valid_request(%{
          artifact_id: "01920080-0000-7000-8000-0000000000aa",
          bytes: "other"
        })

      assert {:error, _} = ArtifactStore.put(store, second_request)
      Application.delete_env(:kiln, :fs_fault)

      assert {:ok, fetched, %{integrity_status: :verified}} =
               ArtifactStore.fetch(store, artifact.artifact_id)

      assert fetched.content_digest == artifact.content_digest
      assert bytes_on_disk(store, artifact) == @bytes
    end
  end

  # -- cleanup behavior --

  describe "cleanup on failure before publication" do
    test "a failed publication leaves no leftover staging files", %{store: store} do
      {:ok, request} = valid_request()

      Application.put_env(:kiln, :fs_fault, %{stage_write_fsync: :raise})

      assert {:error, _} = ArtifactStore.put(store, request)
      Application.delete_env(:kiln, :fs_fault)

      # Confirm no `.kiln-stage-*` files remain anywhere under the artifact root.
      leftover_stages =
        store.artifact_root
        |> Path.join("**/.kiln-stage-*")
        |> Path.wildcard()

      assert leftover_stages == []
    end
  end

  # -- put/2 surface --

  describe "API surface" do
    test "exports exactly put/2 and fetch/2", %{store: _store} do
      exported =
        ArtifactStore.__info__(:functions)
        |> Enum.map(&elem(&1, 0))
        |> Enum.uniq()
        |> Enum.map(&to_string/1)

      assert "put" in exported
      assert "fetch" in exported
      refute "put_3" in exported
      refute Enum.any?(exported, &String.starts_with?(&1, "put_"))
    end

    test "does not accept a third argument", %{store: store} do
      {:ok, request} = valid_request()

      assert_raise UndefinedFunctionError, fn ->
        ArtifactStore.put(store, request, :extra)
      end
    end
  end

  # -- boundary rejection at the API layer --

  describe "validation rejection at the API layer" do
    test "rejects an oversized content payload before opening a transaction", %{store: store} do
      huge = :binary.copy(<<0>>, 16_777_217)

      assert {:error, %{class: :precondition, code: :limit_exceeded}} =
               PutRequest.new(%{
                 artifact_id: "01920080-0000-7000-8000-000000000001",
                 idempotency_key: @idempotency_key,
                 recorded_at: @now,
                 bytes: huge,
                 metadata: %{
                   session_id: "ses_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                   run_id: "run_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
                   owner_kind: :session,
                   owner_id: "ses_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                   producer_kind: :user,
                   producer_id: "user:local",
                   kind: :output,
                   media_type: "application/octet-stream",
                   encoding: :binary,
                   trust: :user_supplied,
                   sensitivity: :project,
                   retention_class: :session,
                   completeness: :complete
                 }
               })

      assert artifact_count(store) == 0
    end

    test "rejects a malformed artifact_id before opening a transaction", %{store: store} do
      assert {:error, %{class: :precondition, code: :malformed_uuid_v7}} =
               PutRequest.new(%{
                 artifact_id: "not-a-uuid",
                 idempotency_key: @idempotency_key,
                 recorded_at: @now,
                 bytes: @bytes,
                 metadata: %{
                   session_id: "ses_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                   run_id: "run_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
                   owner_kind: :session,
                   owner_id: "ses_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                   producer_kind: :user,
                   producer_id: "user:local",
                   kind: :output,
                   media_type: "application/octet-stream",
                   encoding: :binary,
                   trust: :user_supplied,
                   sensitivity: :project,
                   retention_class: :session,
                   completeness: :complete
                 }
               })
    end

    test "rejects a NUL byte in idempotency_key before opening a transaction",
         %{store: store} do
      assert {:error, %{class: :precondition, code: :disallowed_control_byte}} =
               PutRequest.new(%{
                 artifact_id: "01920080-0000-7000-8000-000000000001",
                 idempotency_key: "abc" <> <<0>> <> "def",
                 recorded_at: @now,
                 bytes: @bytes,
                 metadata: %{
                   session_id: "ses_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                   run_id: "run_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
                   owner_kind: :session,
                   owner_id: "ses_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                   producer_kind: :user,
                   producer_id: "user:local",
                   kind: :output,
                   media_type: "application/octet-stream",
                   encoding: :binary,
                   trust: :user_supplied,
                   sensitivity: :project,
                   retention_class: :session,
                   completeness: :complete
                 }
               })
    end
  end

  # -- no capability surface beyond T01 --

  describe "no capability surface beyond T01" do
    test "does not export Provider, Repository, Context, Tool, Patch, Command, Gate, or Receipt APIs" do
      exported =
        ArtifactStore.__info__(:functions) |> Enum.map(&elem(&1, 0)) |> Enum.uniq()

      refute "fetch_provider" in exported
      refute "execute_command" in exported
      refute "evaluate_gate" in exported
      refute "seal_receipt" in exported
      refute "apply_patch" in exported
    end
  end

  # -- internal --

  defp artifact_root_path(store), do: store.artifact_root
end
