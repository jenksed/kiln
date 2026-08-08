defmodule Kiln.Artifact.StoreTest do
  use ExUnit.Case, async: true

  alias Kiln.Artifact.Canonical
  alias Kiln.Artifact.Store
  alias Kiln.Store.{Connection, Error, Migrations}

  @base_attrs %{
    byte_size: 0,
    content_kind: :text,
    encoding: :utf_8,
    media_type: "text/plain",
    retention_class: :durable,
    producer_kind: :internal,
    producer_id: "kiln-test",
    source_digest: "sha256:" <> String.duplicate("0", 64)
  }

  setup do
    dir = Path.join(System.tmp_dir!(), "kiln-artifact-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)

    {:ok, conn} = Connection.start_link(path: Path.join(dir, "state.sqlite3"))
    on_exit(fn -> stop(conn) end)
    {:ok, %{applied_now: [1, 2, 3, 4]}} = Migrations.migrate(conn)

    {:ok, conn: conn}
  end

  describe "content addressing (P1-S02-T01-AC02)" do
    test "the same bytes produce the same artifact_id; a second put is rejected by UNIQUE",
         %{conn: conn} do
      assert {:ok, %{artifact_id: id_a, byte_size: 5}} =
               Store.put(conn, attrs(content_size(5)), "hello")

      assert id_a == Canonical.artifact_id("hello")

      assert {:error, %Error{class: :artifact, code: :persistence_failed}} =
               Store.put(conn, attrs(content_size(5)), "hello")
    end

    test "different bytes produce different artifact_ids", %{conn: conn} do
      assert {:ok, %{artifact_id: id_a}} = Store.put(conn, attrs(content_size(5)), "hello")
      assert {:ok, %{artifact_id: id_b}} = Store.put(conn, attrs(content_size(5)), "world")

      assert id_a != id_b
    end

    test "an empty payload is accepted with byte_size 0", %{conn: conn} do
      assert {:ok, %{artifact_id: id, byte_size: 0}} =
               Store.put(conn, attrs(content_size(0)), "")

      assert id == Canonical.artifact_id("")
    end
  end

  describe "bounded vocabulary rejection (P1-S02-T01-AC03)" do
    test "an unknown content_kind is rejected without writing a row", %{conn: conn} do
      assert {:error,
              %Error{class: :artifact, code: :invalid_field, details: %{field: :content_kind}}} =
               Store.put(conn, %{@base_attrs | content_kind: :bogus}, "x")

      assert [] = Connection.query!(conn, "SELECT artifact_id FROM artifacts")
    end

    test "an unknown encoding is rejected without writing a row", %{conn: conn} do
      assert {:error,
              %Error{class: :artifact, code: :invalid_field, details: %{field: :encoding}}} =
               Store.put(conn, %{@base_attrs | encoding: :utf_16}, "x")

      assert [] = Connection.query!(conn, "SELECT artifact_id FROM artifacts")
    end

    test "an unknown retention_class is rejected without writing a row", %{conn: conn} do
      assert {:error,
              %Error{class: :artifact, code: :invalid_field, details: %{field: :retention_class}}} =
               Store.put(conn, %{@base_attrs | retention_class: :ephemeral}, "x")

      assert [] = Connection.query!(conn, "SELECT artifact_id FROM artifacts")
    end

    test "an unknown producer_kind is rejected without writing a row", %{conn: conn} do
      assert {:error,
              %Error{class: :artifact, code: :invalid_field, details: %{field: :producer_kind}}} =
               Store.put(conn, %{@base_attrs | producer_kind: :oracle}, "x")

      assert [] = Connection.query!(conn, "SELECT artifact_id FROM artifacts")
    end

    test "an empty media_type is rejected", %{conn: conn} do
      assert {:error,
              %Error{class: :artifact, code: :invalid_field, details: %{field: :media_type}}} =
               Store.put(conn, %{@base_attrs | media_type: ""}, "x")
    end

    test "an empty producer_id is rejected", %{conn: conn} do
      assert {:error,
              %Error{class: :artifact, code: :invalid_field, details: %{field: :producer_id}}} =
               Store.put(conn, %{@base_attrs | producer_id: ""}, "x")
    end

    test "a malformed source_digest is rejected", %{conn: conn} do
      assert {:error, %Error{class: :artifact, code: :invalid_digest_format}} =
               Store.put(conn, %{@base_attrs | source_digest: "sha256:not-hex"}, "x")
    end

    test "a declared byte_size that does not match actual bytes is rejected", %{conn: conn} do
      assert {:error, %Error{class: :artifact, code: :content_mismatch}} =
               Store.put(conn, %{@base_attrs | byte_size: 999}, "x")

      assert [] = Connection.query!(conn, "SELECT artifact_id FROM artifacts")
    end

    test "a negative byte_size is rejected", %{conn: conn} do
      assert {:error,
              %Error{class: :artifact, code: :invalid_field, details: %{field: :byte_size}}} =
               Store.put(conn, %{@base_attrs | byte_size: -1}, "x")
    end
  end

  describe "replay_attack (P1-S02-T01-AC05 / R06)" do
    test "a re-insert of the identical content is rejected by the SQLite UNIQUE constraint", %{
      conn: conn
    } do
      assert {:ok, %{artifact_id: _id}} = Store.put(conn, attrs(content_size(5)), "hello")

      assert {:error, %Error{class: :artifact, code: :persistence_failed}} =
               Store.put(conn, attrs(content_size(5)), "hello")
    end
  end

  describe "stored row binds to exact state (P1-S02-T01-AC07)" do
    test "the persisted row carries every required column", %{conn: conn} do
      recorded_at = "2026-08-08T01:23:45Z"

      assert {:ok, %{artifact_id: id}} =
               Store.put(conn, attrs(content_size(5), recorded_at: recorded_at), "hello")

      [
        [
          artifact_id,
          byte_size,
          content_kind,
          encoding,
          media_type,
          retention_class,
          producer_kind,
          producer_id,
          recorded_at_db,
          source_digest,
          schema,
          content
        ]
      ] =
        Connection.query!(
          conn,
          """
          SELECT artifact_id, byte_size, content_kind, encoding, media_type,
                 retention_class, producer_kind, producer_id, recorded_at,
                 source_digest, schema, content
          FROM artifacts WHERE artifact_id = ?1
          """,
          [id]
        )

      assert artifact_id == id
      assert byte_size == 5
      assert content_kind == "text"
      assert encoding == "utf_8"
      assert media_type == "text/plain"
      assert retention_class == "durable"
      assert producer_kind == "internal"
      assert producer_id == "kiln-test"
      assert recorded_at_db == recorded_at
      assert source_digest == "sha256:" <> String.duplicate("0", 64)
      assert schema == "kiln.artifact/v1"
      assert content == "hello"
    end
  end

  defp attrs(overrides) when is_map(overrides) do
    Map.merge(@base_attrs, overrides)
  end

  defp attrs(overrides, keyword_overrides)
       when is_map(overrides) and is_list(keyword_overrides) do
    @base_attrs
    |> Map.merge(overrides)
    |> Map.merge(Enum.into(keyword_overrides, %{}))
  end

  defp content_size(n), do: %{byte_size: n}

  defp stop(conn) do
    if Process.alive?(conn), do: GenServer.stop(conn)
    :ok
  catch
    :exit, _reason -> :ok
  end
end
