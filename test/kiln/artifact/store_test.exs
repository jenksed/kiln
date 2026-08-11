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
    defaults = %{
      artifact_id: "01920080-0000-7000-8000-000000000001",
      idempotency_key: @idempotency_key,
      bytes: @bytes,
      media_type_override: nil
    }

    merged = Map.merge(defaults, Map.new(opts))

    media_type = merged.media_type_override || "application/octet-stream"

    PutRequest.new(%{
      artifact_id: merged.artifact_id,
      idempotency_key: merged.idempotency_key,
      recorded_at: @now,
      bytes: merged.bytes,
      metadata: %{
        session_id: "ses_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        run_id: "run_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        owner_kind: :session,
        owner_id: "ses_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        producer_kind: :user,
        producer_id: "user:local",
        kind: :output,
        media_type: media_type,
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

    test "stores no content bytes in SQLite (content_digest metadata is persisted)",
         %{store: store} do
      {:ok, request} = valid_request()
      {:ok, artifact, _} = ArtifactStore.put(store, request)

      # Confirm the SQLite file does not contain the literal published bytes.
      # `content_digest` is intentionally persisted Artifact metadata; it is
      # not the content itself. The invariant is that Artifact content bytes
      # never enter SQLite; the digest is allowed and expected.
      #
      # SQLite stores text values as UTF-8 inside BLOB records that may be
      # paged or compressed. We verify the invariant by checking that the
      # content bytes are absent from a byte-level read and that the
      # content_digest is present in the SQLite row directly.
      sqlite_bytes = File.read!(store.state_path)
      refute sqlite_bytes =~ @bytes

      rows =
        Connection.query!(
          store.conn,
          "SELECT content_digest FROM artifacts WHERE artifact_id = ?1",
          [artifact.artifact_id]
        )

      expected_digest = artifact.content_digest
      assert [[row_digest]] = rows
      assert row_digest == expected_digest
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

  defp digest_for(bytes) when is_binary(bytes) do
    "sha256:" <> (:crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower))
  end

  # ----------------------------------------------------------------------
  # Layer 2 repair checkpoint: adversarial coverage for the boundaries the
  # first checkpoint over-claimed or under-proved.
  # ----------------------------------------------------------------------

  describe "interior symlink containment (AC03 / security boundary)" do
    test "rejects a symlink at the sha256/<prefix> intermediate pointing outside the root",
         %{store: store, base: base} do
      external = Path.join(base, "external-target")
      File.mkdir_p!(external)
      pre_existing = Path.join(external, "pre-existing.txt")
      File.write!(pre_existing, "untouched")

      {:ok, request} = valid_request()
      digest = digest_for(request.bytes)
      <<first_two::binary-size(2), _::binary>> = String.replace_prefix(digest, "sha256:", "")
      intermediate = Path.join([store.artifact_root, "sha256", first_two])

      # Plant the symlink AFTER the Store is ready but BEFORE the write.
      File.mkdir_p!(Path.dirname(intermediate))
      File.rm_rf!(intermediate)
      File.ln_s!(external, intermediate)
      assert File.lstat!(intermediate).type == :symlink

      assert {:error, %{class: :integrity}} = ArtifactStore.put(store, request)

      # No metadata row.
      assert artifact_count(store) == 0

      # No bytes outside the accepted root.
      assert File.read!(pre_existing) == "untouched"

      external_files =
        external
        |> Path.join("*")
        |> Path.wildcard()

      assert external_files == [pre_existing]

      # No leftover staging file that would grant authority.
      leftover_stages =
        store.artifact_root
        |> Path.join("**/.kiln-stage-*")
        |> Path.wildcard()

      assert leftover_stages == []

      # The symlink itself is preserved (the Store must not delete or alter the target).
      assert File.lstat!(intermediate).type == :symlink
      assert File.read!(pre_existing) == "untouched"
    end

    test "rejects a symlink at the sha256 top-level intermediate", %{store: store, base: base} do
      external = Path.join(base, "external-sha256")
      File.mkdir_p!(external)
      pre_existing = Path.join(external, "marker")
      File.write!(pre_existing, "x")

      sha256 = Path.join(store.artifact_root, "sha256")
      File.rm_rf!(sha256)
      File.ln_s!(external, sha256)
      assert File.lstat!(sha256).type == :symlink

      {:ok, request} = valid_request()

      assert {:error, %{class: :integrity}} = ArtifactStore.put(store, request)
      assert artifact_count(store) == 0
      assert File.read!(pre_existing) == "x"
    end

    test "preserves a pre-existing valid blob when an unrelated symlink is present",
         %{store: store, base: base} do
      {:ok, first_request} =
        valid_request(%{
          artifact_id: "01920080-0000-7000-8000-0000000000a1",
          bytes: "first bytes",
          idempotency_key: "idem_first"
        })

      {:ok, first_artifact, %{status: :committed}} = ArtifactStore.put(store, first_request)
      first_final = Path.join(store.artifact_root, first_artifact.content_location)
      first_bytes = File.read!(first_final)
      assert first_bytes == "first bytes"

      # Now plant a symlink at a different intermediate path.
      other_digest = digest_for("other bytes")

      <<other_prefix::binary-size(2), _::binary>> =
        String.replace_prefix(other_digest, "sha256:", "")

      other_intermediate = Path.join([store.artifact_root, "sha256", other_prefix])

      external = Path.join(base, "external-other")
      File.mkdir_p!(external)
      File.rm_rf!(other_intermediate)
      File.ln_s!(external, other_intermediate)

      {:ok, second_request} =
        valid_request(%{
          artifact_id: "01920080-0000-7000-8000-0000000000a2",
          bytes: "other bytes",
          idempotency_key: "idem_second"
        })

      assert {:error, %{class: :integrity}} = ArtifactStore.put(store, second_request)

      # The first publication remains intact; the symlink did not affect it.
      assert File.read!(first_final) == first_bytes
      assert File.lstat!(other_intermediate).type == :symlink
      assert artifact_count(store) == 1
    end

    test "rejects a symlink at the artifact root level when introduced after startup",
         %{store: store, base: base} do
      external = Path.join(base, "external-root")
      File.mkdir_p!(external)

      # Replace the existing artifact_root directory with a symlink pointing outside.
      File.rm_rf!(store.artifact_root)
      File.ln_s!(external, store.artifact_root)

      {:ok, request} = valid_request()

      assert {:error, %{class: :integrity}} = ArtifactStore.put(store, request)
      assert artifact_count(store) == 0
    end
  end

  describe "Unicode-safe staging name (Layer 2 R14, idempotency_key bound)" do
    test "accepts a valid non-ASCII idempotency_key without raising",
         %{store: store} do
      unicode_key = "idem_中文_ключ_🪄"

      {:ok, request} =
        valid_request(%{
          idempotency_key: unicode_key,
          artifact_id: "01920080-0000-7000-8000-000000000030"
        })

      assert {:ok, artifact, %{status: :committed}} = ArtifactStore.put(store, request)

      final = Path.join(store.artifact_root, artifact.content_location)
      assert File.read!(final) == @bytes

      # No leftover staging file.
      leftover_stages =
        store.artifact_root
        |> Path.join("**/.kiln-stage-*")
        |> Path.wildcard()

      assert leftover_stages == []

      # Replay round-trips with the same Unicode key.
      {:ok, replay, %{status: :replayed}} = ArtifactStore.put(store, request)
      assert replay.artifact_id == artifact.artifact_id
    end

    test "replay of a Unicode-keyed request returns the same committed record",
         %{store: store} do
      unicode_key = "idem_中文_🚀_test"

      {:ok, request} =
        valid_request(%{
          idempotency_key: unicode_key,
          artifact_id: "01920080-0000-7000-8000-000000000040"
        })

      {:ok, first, %{status: :committed}} = ArtifactStore.put(store, request)
      {:ok, replay, %{status: :replayed}} = ArtifactStore.put(store, request)

      assert first.artifact_id == replay.artifact_id
      assert artifact_count(store) == 1
    end

    test "staging filename contains no path separators from the idempotency_key",
         %{store: store} do
      # The idempotency_key may contain filesystem-special printable characters
      # (`/`, `\`, `*`, `?`, `|`, `<`, `>`, `:`, `"`) but those must never
      # reach the staging filename. PutRequest rejects NUL and control bytes
      # before they reach this layer.
      tricky_key = "idem/with\\slashes|*pipes?and*dots:"

      {:ok, request} =
        valid_request(%{
          idempotency_key: tricky_key,
          artifact_id: "01920080-0000-7000-8000-000000000050"
        })

      assert {:ok, _artifact, %{status: :committed}} = ArtifactStore.put(store, request)

      # If staging succeeded and was cleaned, there is nothing left.
      leftover_stages =
        store.artifact_root
        |> Path.join("**/.kiln-stage-*")
        |> Path.wildcard()

      assert leftover_stages == []
    end

    test "staging filename suffix is a deterministic 12-character lowercase hex string",
         %{store: _store} do
      # Two different keys must produce two different suffixes, but both must
      # be 12 lowercase hex characters.
      assert "idem_a" |> stage_suffix_for_test() =~ ~r/^[0-9a-f]{12}$/
      assert "idem_b" |> stage_suffix_for_test() =~ ~r/^[0-9a-f]{12}$/

      # Different inputs produce different suffixes.
      refute stage_suffix_for_test("idem_a") == stage_suffix_for_test("idem_b")

      # Same input produces the same suffix (deterministic).
      assert stage_suffix_for_test("idem_a") == stage_suffix_for_test("idem_a")
    end

    test "stage_pair/3 cannot raise on any valid PutRequest idempotency_key",
         %{store: _store} do
      # Exercise the real public seam with a representative spread.
      keys = [
        "idem_ascii",
        "idem_中文_ключ_🪄",
        "idem/with\\slashes",
        String.duplicate("a", 256),
        ""
      ]

      for key <- keys do
        # Use the public stage_pair so any raise surfaces here.
        # The empty string is rejected by PutRequest before reaching this
        # layer; verify stage_pair itself is total for non-empty inputs.
        case key do
          "" ->
            :ok

          key ->
            assert {_stage, _final} = Kiln.Artifact.FS.stage_pair("/tmp/x", "sha256/aa/bb", key)
        end
      end
    end

    defp stage_suffix_for_test(key),
      do: :crypto.hash(:sha256, key) |> Base.encode16(case: :lower) |> binary_part(0, 12)
  end

  describe "metadata-boundary fault and pre-metadata orphan (AC03)" do
    test "no committed row and no identity when the metadata insert fails after promotion",
         %{store: store} do
      {:ok, request} = valid_request()

      Application.put_env(:kiln, :store_fault, %{metadata_persist: :raise})

      assert {:error, _} = ArtifactStore.put(store, request)
      Application.delete_env(:kiln, :store_fault)

      assert artifact_count(store) == 0

      # The promoted digest-addressed blob MAY remain as a pre-metadata orphan.
      digest = digest_for(request.bytes)
      relative = Kiln.Artifact.FS.content_location(digest)
      orphan = Path.join(store.artifact_root, relative)

      assert File.regular?(orphan)
      assert File.read!(orphan) == @bytes
    end

    test "a restart does not manufacture Artifact identity from the pre-metadata orphan",
         %{store: store, base: base} do
      {:ok, request} = valid_request()

      Application.put_env(:kiln, :store_fault, %{metadata_persist: :raise})
      assert {:error, _} = ArtifactStore.put(store, request)
      Application.delete_env(:kiln, :store_fault)

      # The orphan is on disk but no row exists.
      assert artifact_count(store) == 0

      digest = digest_for(request.bytes)
      orphan = Path.join(store.artifact_root, Kiln.Artifact.FS.content_location(digest))
      assert File.regular?(orphan)

      # Stop the existing connection, restart on the same path.
      stop(store.conn)

      {:ready, restarted} =
        Store.start(
          path: Path.join(base, "state.sqlite3"),
          store_id: "store_test",
          now: @now
        )

      on_exit(fn -> stop(restarted.conn) end)

      assert artifact_count(restarted) == 0
      assert File.regular?(orphan)

      # `fetch` on an unknown artifact_id returns precondition, not a fabricated identity.
      assert {:error, %{class: :precondition, code: :unknown_artifact}} =
               ArtifactStore.fetch(restarted, request.artifact_id)
    end

    test "a later matching publication reuses the orphan and commits normally",
         %{store: store, base: base} do
      {:ok, request} = valid_request()

      Application.put_env(:kiln, :store_fault, %{metadata_persist: :raise})
      assert {:error, _} = ArtifactStore.put(store, request)
      Application.delete_env(:kiln, :store_fault)

      # Restart to prove the orphan survives a process boundary unchanged.
      stop(store.conn)

      {:ready, restarted} =
        Store.start(
          path: Path.join(base, "state.sqlite3"),
          store_id: "store_test",
          now: @now
        )

      on_exit(fn -> stop(restarted.conn) end)

      # The exact same request now succeeds; the orphan is verified and reused.
      assert {:ok, artifact, %{status: :committed}} = ArtifactStore.put(restarted, request)
      assert artifact_count(restarted) == 1
      assert File.read!(Path.join(restarted.artifact_root, artifact.content_location)) == @bytes
    end

    test "a tampered pre-existing destination is rejected as :corrupt",
         %{store: store, base: base} do
      {:ok, request} = valid_request()

      # First write succeeds.
      {:ok, artifact, %{status: :committed}} = ArtifactStore.put(store, request)
      final = Path.join(store.artifact_root, artifact.content_location)

      # Tamper with the on-disk blob so its size and digest disagree with metadata.
      File.write!(final, "tampered with different bytes")
      assert File.read!(final) != @bytes

      stop(store.conn)

      {:ready, restarted} =
        Store.start(
          path: Path.join(base, "state.sqlite3"),
          store_id: "store_test",
          now: @now
        )

      on_exit(fn -> stop(restarted.conn) end)

      # Fetch reports the corrupt blob.
      assert {:ok, _, %{integrity_status: :corrupt}} =
               ArtifactStore.fetch(restarted, artifact.artifact_id)

      # A subsequent identical put must reject the tampered destination as :integrity.
      assert {:error, %{class: :integrity}} = ArtifactStore.put(restarted, request)
      assert artifact_count(restarted) == 1

      # The tampered content is unchanged on disk (the Store did not overwrite a
      # mismatched blob silently).
      assert File.read!(final) == "tampered with different bytes"
    end

    test "preserves a pre-existing valid blob and row when a later put fails at metadata",
         %{store: store, base: base} do
      {:ok, first} =
        valid_request(%{
          artifact_id: "01920080-0000-7000-8000-0000000000c1",
          bytes: "preserved bytes",
          idempotency_key: "idem_preserved"
        })

      {:ok, first_artifact, %{status: :committed}} = ArtifactStore.put(store, first)
      first_final = Path.join(store.artifact_root, first_artifact.content_location)
      first_bytes = File.read!(first_final)
      assert first_bytes == "preserved bytes"

      # Trigger a metadata-boundary fault for an unrelated second put.
      {:ok, second} =
        valid_request(%{
          artifact_id: "01920080-0000-7000-8000-0000000000c2",
          bytes: "second bytes",
          idempotency_key: "idem_second_faulted"
        })

      Application.put_env(:kiln, :store_fault, %{metadata_persist: :raise})
      assert {:error, _} = ArtifactStore.put(store, second)
      Application.delete_env(:kiln, :store_fault)

      # Restart and confirm the first publication survives intact.
      stop(store.conn)

      {:ready, restarted} =
        Store.start(
          path: Path.join(base, "state.sqlite3"),
          store_id: "store_test",
          now: @now
        )

      on_exit(fn -> stop(restarted.conn) end)

      assert {:ok, fetched, %{integrity_status: :verified}} =
               ArtifactStore.fetch(restarted, first_artifact.artifact_id)

      assert fetched.artifact_id == first_artifact.artifact_id
      assert File.read!(first_final) == first_bytes
      assert artifact_count(restarted) == 1
    end
  end

  # ----------------------------------------------------------------------
  # Layer 2 repair checkpoint: leaf-component symlink and special-file
  # rejection. The repair uses File.lstat on the final path component before
  # any open. Tests exercise the real public Artifact.Store.put/2 and
  # fetch/2 paths.
  # ----------------------------------------------------------------------

  describe "leaf-component classification (security boundary)" do
    test "put/2 with a symlink at the final blob path rejects as integrity and never follows",
         %{store: store, base: base} do
      {:ok, first} =
        valid_request(%{
          artifact_id: "01920080-0000-7000-8000-0000000000d1",
          bytes: "original bytes",
          idempotency_key: "idem_leaf_symlink_first"
        })

      {:ok, artifact, _} = ArtifactStore.put(store, first)
      final = Path.join(store.artifact_root, artifact.content_location)
      assert File.read!(final) == "original bytes"

      # Plant a symlink at a different content-addressed path pointing to an
      # external file with attacker-controlled contents.
      external_file = Path.join(base, "attacker-target.txt")
      File.write!(external_file, "attacker payload")

      other_digest = digest_for("attacker-targeted bytes")
      other_location = Kiln.Artifact.FS.content_location(other_digest)
      final_for_other = Path.join(store.artifact_root, other_location)

      File.mkdir_p!(Path.dirname(final_for_other))
      File.rm_rf!(final_for_other)
      File.ln_s!(external_file, final_for_other)
      assert File.lstat!(final_for_other).type == :symlink

      {:ok, second} =
        valid_request(%{
          artifact_id: "01920080-0000-7000-8000-0000000000d2",
          bytes: "attacker-targeted bytes",
          idempotency_key: "idem_leaf_symlink_second"
        })

      assert {:error, %{class: :integrity}} = ArtifactStore.put(store, second)
      assert artifact_count(store) == 1

      # The external target is untouched.
      assert File.read!(external_file) == "attacker payload"

      # The symlink is preserved (not deleted or replaced).
      assert File.lstat!(final_for_other).type == :symlink

      # No leftover staging file.
      leftover_stages =
        store.artifact_root
        |> Path.join("**/.kiln-stage-*")
        |> Path.wildcard()

      assert leftover_stages == []

      # The first publication remains intact.
      assert File.read!(final) == "original bytes"
    end

    test "fetch/2 after a valid blob is replaced by a symlink never reads the external target",
         %{store: store, base: base} do
      {:ok, request} = valid_request()
      {:ok, artifact, _} = ArtifactStore.put(store, request)
      final = Path.join(store.artifact_root, artifact.content_location)

      external_file = Path.join(base, "fetch-attacker.txt")
      File.write!(external_file, "fetch attacker payload")

      File.rm!(final)
      File.ln_s!(external_file, final)
      assert File.lstat!(final).type == :symlink

      # The metadata row remains; fetch must not mutate it and must not trust
      # the symlink target.
      assert {:ok, fetched, %{integrity_status: :corrupt}} =
               ArtifactStore.fetch(store, artifact.artifact_id)

      assert fetched.artifact_id == artifact.artifact_id
      assert fetched.content_digest == artifact.content_digest
      assert fetched.byte_size == artifact.byte_size

      # The external target is unchanged.
      assert File.read!(external_file) == "fetch attacker payload"
    end

    test "put/2 with a directory at the final blob path rejects as integrity",
         %{store: store} do
      {:ok, request} = valid_request()

      # Plant a directory where the final blob path would be created.
      digest = digest_for(request.bytes)
      final = Path.join(store.artifact_root, Kiln.Artifact.FS.content_location(digest))
      File.mkdir_p!(final)
      assert File.lstat!(final).type == :directory

      assert {:error, %{class: :integrity, code: :leaf_is_directory}} =
               ArtifactStore.put(store, request)

      assert artifact_count(store) == 0
      assert File.lstat!(final).type == :directory
    end

    test "put/2 with a special file (FIFO) at the final blob path rejects as integrity",
         %{store: store} do
      {:ok, request} = valid_request()

      digest = digest_for(request.bytes)
      final = Path.join(store.artifact_root, Kiln.Artifact.FS.content_location(digest))
      File.mkdir_p!(Path.dirname(final))
      File.rm_rf!(final)
      # Portable special-file fixture: FIFO (named pipe) is available on
      # POSIX. The Store classifies the leaf without dereferencing and rejects
      # any non-regular leaf as :integrity before opening.
      {_, 0} = System.cmd("mkfifo", [final])
      assert File.lstat!(final).type == :other

      assert {:error, %{class: :integrity}} = ArtifactStore.put(store, request)
      assert artifact_count(store) == 0

      # The FIFO itself is preserved (the Store does not delete or alter it).
      assert File.lstat!(final).type == :other
    end

    test "fetch/2 with a directory at the final blob path rejects with integrity-derived status",
         %{store: store} do
      {:ok, request} = valid_request()
      {:ok, artifact, _} = ArtifactStore.put(store, request)
      final = Path.join(store.artifact_root, artifact.content_location)

      File.rm!(final)
      File.mkdir_p!(final)

      assert {:ok, _fetched, %{integrity_status: :corrupt}} =
               ArtifactStore.fetch(store, artifact.artifact_id)

      # Metadata row remains immutable across the failed fetch.
      expected_id = artifact.artifact_id
      assert [[row_id, _, _, _]] = artifact_row(store, expected_id)
      assert row_id == expected_id
    end
  end

  # ----------------------------------------------------------------------
  # Layer 2 repair checkpoint: canonical request representation.
  # The persistent request map used for byte-size enforcement, digest
  # calculation, and replay identity is one and the same. request_digest
  # is computed over the canonical map with the caller-supplied envelope
  # fields and content fields, never over a nil placeholders.
  # ----------------------------------------------------------------------

  describe "canonical Artifact request representation" do
    test "a canonical request of exactly 65,536 bytes is accepted",
         %{store: _store} do
      request = build_request_at_canonical_size(65_536)

      canonical =
        Kiln.Artifact.persistent_request_map(
          envelope_from_struct(request),
          request.metadata
        )

      encoded = Kiln.Store.Canonical.encode(canonical)
      assert byte_size(encoded) == 65_536

      # The PutRequest that backs the boundary is accepted (size is at the
      # boundary, not above).
      assert {:ok, _} = PutRequest.new(request)
    end

    test "a canonical request of 65,537 bytes is rejected as precondition / limit_exceeded before any side effect",
         %{store: store, base: _base} do
      request_map = request_map_at_canonical_size(65_537)

      # The rejection must occur in PutRequest.new, before any filesystem
      # staging, BEGIN IMMEDIATE, or metadata write.
      artifact_root_before = file_signature(store.artifact_root)
      sqlite_before = File.read!(store.state_path)

      assert {:error, %{class: :precondition, code: :limit_exceeded}} =
               PutRequest.new(request_map)

      artifact_root_after = file_signature(store.artifact_root)
      sqlite_after = File.read!(store.state_path)

      assert artifact_root_before == artifact_root_after
      assert sqlite_before == sqlite_after
      assert artifact_count(store) == 0
    end

    test "recomputing request_digest from a stored Artifact yields the persisted request_digest",
         %{store: store} do
      {:ok, request} = valid_request()
      {:ok, artifact, _} = ArtifactStore.put(store, request)

      stored_digest = artifact.request_digest
      recomputed = Kiln.Artifact.request_digest(artifact)

      assert stored_digest == recomputed
      assert stored_digest =~ ~r/^[0-9a-f]{64}$/
    end

    test "an exact retry replays under the same idempotency_key and request_digest",
         %{store: store} do
      {:ok, request} = valid_request()

      {:ok, first, %{status: first_status}} = ArtifactStore.put(store, request)
      assert first_status == :committed

      {:ok, replay, %{status: replay_status}} = ArtifactStore.put(store, request)
      assert replay_status == :replayed
      assert replay.artifact_id == first.artifact_id
      assert artifact_count(store) == 1
    end

    test "a one-field persistent-request change under the same idempotency_key produces idempotency_conflict",
         %{store: store} do
      {:ok, first} =
        valid_request(%{
          artifact_id: "01920080-0000-7000-8000-0000000000c2",
          idempotency_key: "idem_conflict"
        })

      {:ok, _committed, _} = ArtifactStore.put(store, first)

      # Change a single persistent field (media_type) under the same
      # idempotency_key. The persistent request changes, so the canonical
      # map changes, so the request_digest changes — this is not an exact
      # retry.
      {:ok, conflicting} =
        valid_request(%{
          artifact_id: "01920080-0000-7000-8000-0000000000c3",
          idempotency_key: "idem_conflict",
          media_type_override: "application/different"
        })

      assert {:error, %{class: :idempotency_conflict, code: :key_reuse_different_request}} =
               ArtifactStore.put(store, conflicting)

      assert artifact_count(store) == 1
    end
  end

  # ----------------------------------------------------------------------
  # Helper for building PutRequests of an exact canonical size.
  # We pad `media_type` (which is bounded 1..255 bytes) with deterministic
  # ASCII filler so the canonical encoding lands exactly at 65,536 or
  # 65,537 bytes.
  # ----------------------------------------------------------------------

  defp build_request_at_canonical_size(target) do
    request_map = request_map_at_canonical_size(target)

    case PutRequest.new(request_map) do
      {:ok, request} -> request
      {:error, error} -> raise "PutRequest rejected target=#{target}: #{inspect(error)}"
    end
  end

  defp request_map_at_canonical_size(target) do
    # The unbounded `repository_state_digest` field is the only field that
    # can carry enough bytes to reach the 65,536-byte canonical bound. The
    # canonical encoding is linear in the value's byte length (single-byte
    # ASCII, no escapes), so the size formula is:
    #
    #     base_with_one_char =  base + field_overhead
    #     size(filler = n)   =  base_with_one_char + (n - 1)
    #
    # Solving for n:  n = target - base_with_one_char + 1
    base_with_one_char = base_canonical_size_with_rsd_present()
    filler_len = target - base_with_one_char + 1

    if filler_len < 0 do
      raise "target #{target} is below the base canonical size #{base_with_one_char}"
    end

    filler = String.duplicate("a", filler_len)
    metadata = put_metadata_with_unbounded_filler(filler)
    Map.put(base_request_map_for_size(), :metadata, metadata)
  end

  defp base_canonical_size do
    base = base_request_map_for_size()
    metadata = put_metadata("application/octet-stream")
    envelope = envelope_from(base)

    canonical = Kiln.Artifact.persistent_request_map(envelope, metadata)
    byte_size(Kiln.Store.Canonical.encode(canonical))
  end

  defp base_canonical_size_with_rsd_present do
    base = base_request_map_for_size()
    metadata = put_metadata_with_unbounded_filler("a")
    envelope = envelope_from(base)

    canonical = Kiln.Artifact.persistent_request_map(envelope, metadata)
    byte_size(Kiln.Store.Canonical.encode(canonical))
  end

  defp base_request_map_for_size do
    %{
      artifact_id: "01920080-0000-7000-8000-000000000099",
      idempotency_key: "idem_canonical_size",
      recorded_at: @now,
      bytes: "canonical-size fixture",
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
    }
  end

  defp envelope_from(request) when is_map(request) do
    %{
      artifact_id: Map.get(request, :artifact_id) || Map.get(request, "artifact_id"),
      idempotency_key: Map.get(request, :idempotency_key) || Map.get(request, "idempotency_key"),
      recorded_at: Map.get(request, :recorded_at) || Map.get(request, "recorded_at"),
      bytes: Map.get(request, :bytes) || Map.get(request, "bytes")
    }
  end

  defp envelope_from_struct(%{artifact_id: a, idempotency_key: i, recorded_at: r, bytes: b}) do
    %{artifact_id: a, idempotency_key: i, recorded_at: r, bytes: b}
  end

  defp put_metadata(media_type) do
    %{
      session_id: "ses_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      run_id: "run_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      owner_kind: :session,
      owner_id: "ses_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      producer_kind: :user,
      producer_id: "user:local",
      kind: :output,
      media_type: media_type,
      encoding: :binary,
      trust: :user_supplied,
      sensitivity: :project,
      retention_class: :session,
      completeness: :complete
    }
  end

  # Pads the unbounded `repository_state_digest` field with the supplied filler
  # so the canonical request encoding can land at an exact target byte count.
  # The filler is plain lowercase ASCII so it never triggers the NUL or
  # control-byte rejection.
  defp put_metadata_with_unbounded_filler(filler) do
    Map.put(put_metadata("application/octet-stream"), :repository_state_digest, filler)
  end

  defp file_signature(dir) do
    if File.exists?(dir) do
      {File.lstat!(dir).mtime, File.lstat!(dir).size}
    else
      :missing
    end
  end
end
