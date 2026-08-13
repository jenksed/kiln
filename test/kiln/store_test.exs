defmodule Kiln.StoreTest do
  use ExUnit.Case, async: true

  alias Kiln.Store
  alias Kiln.Store.Connection

  setup do
    dir = Path.join(System.tmp_dir!(), "kiln-startup-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, path: Path.join(dir, "state.sqlite3")}
  end

  test "starts ready on an empty directory with verified schema, pragmas, and version", %{
    path: path
  } do
    assert {:ready, store} =
             Store.start(path: path, store_id: "store_fixture", now: "2026-07-29T00:00:00Z")

    on_exit(fn -> stop(store.conn) end)

    assert store.store_version == 6
    assert store.store_format == "kiln-state/v1"
    assert store.store_id == "store_fixture"

    assert store.info.journal_mode == "wal"
    assert store.info.synchronous == 2
    assert store.info.foreign_keys == 1
    assert store.info.busy_timeout == 2000
    assert store.info.quick_check == "ok"

    parts =
      store.sqlite_version
      |> String.split(".")
      |> Enum.map(&String.to_integer/1)
      |> List.to_tuple()

    assert parts >= {3, 51, 3}

    assert [[1, _], [2, checksum], [3, _], [4, _], [5, _], [6, _]] =
             Connection.query!(
               store.conn,
               "SELECT version, checksum FROM schema_migrations ORDER BY version"
             )

    assert String.length(checksum) == 64

    assert [["kiln-state/v1", "store_fixture"]] =
             Connection.query!(store.conn, "SELECT store_format, store_id FROM store_metadata")
  end

  test "restarts against an existing store without reapplying or changing identity", %{path: path} do
    {:ready, first} =
      Store.start(path: path, store_id: "store_fixture", now: "2026-07-29T00:00:00Z")

    stop(first.conn)

    assert {:ready, second} = Store.start(path: path)
    on_exit(fn -> stop(second.conn) end)

    assert second.store_version == 6
    assert second.store_id == "store_fixture"
  end

  test "start_link exposes the supervised connection on a ready store", %{path: path} do
    assert {:ok, conn} = Store.start_link(path: path, store_id: "store_fixture", now: "t0")
    on_exit(fn -> stop(conn) end)

    assert [[6]] = Connection.query!(conn, "SELECT count(*) FROM schema_migrations")
    assert is_pid(conn)
  end

  test "start_link fails the child start when the store is blocked", %{path: path} do
    File.write!(path, :crypto.strong_rand_bytes(2048))

    assert {:error, {:integrity_blocked, %{class: :integrity}}} = Store.start_link(path: path)
  end

  test "version-blocks an unsupported store format and closes the rejected connection", %{
    path: path
  } do
    {:ready, store} =
      Store.start(path: path, store_id: "store_fixture", now: "2026-07-29T00:00:00Z")

    Connection.query!(
      store.conn,
      "UPDATE store_metadata SET store_format = 'kiln-state/v2' WHERE id = 1"
    )

    stop(store.conn)

    name = String.to_atom("kiln_blocked_store_#{System.unique_integer([:positive])}")

    assert {:blocked, :version_blocked,
            %{class: :future_version, code: :unsupported_store_format}} =
             Store.start(path: path, name: name)

    refute Process.whereis(name)
  end

  defp stop(conn) do
    if Process.alive?(conn), do: GenServer.stop(conn)
    :ok
  catch
    :exit, _reason -> :ok
  end
end
