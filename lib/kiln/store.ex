defmodule Kiln.Store do
  @moduledoc """
  Public startup boundary for the first-month SQLite state store.

  `start/1` opens the supervised connection, verifies the accepted pragmas and
  bundled SQLite version, verifies or initializes the store format metadata, and
  runs pending migrations, following the P0-W21 startup sequence. It yields one
  startup outcome and never leaves a writable connection alive after a blocked
  or failed startup.

  `Kiln.Store.Journal.commit/4` owns the atomic application-action transaction
  after startup reaches `:ready`.
  """

  alias Kiln.Store.{Connection, Error, Migrations}

  @store_format "kiln-state/v1"
  @supported_formats [@store_format]

  @typedoc "A ready store and its verified facts."
  @type store :: %{
          conn: Connection.conn(),
          store_id: String.t(),
          store_format: String.t(),
          store_version: non_neg_integer(),
          sqlite_version: String.t(),
          state_path: String.t(),
          artifact_root: String.t(),
          info: Connection.info()
        }

  @typedoc "A blocking startup outcome that never exposes a writable store."
  @type blocked_state ::
          :busy | :migration_blocked | :integrity_blocked | :version_blocked | :unavailable

  @doc """
  Start and validate the store at `opts[:path]`.

  Returns:

    * `{:ready, store}` when every startup check passes;
    * `{:blocked, state, error}` for a classified startup failure that preserves
      files and exposes no writable store;
    * `{:error, reason}` when the connection process cannot start.

  Options: `:path` (required), `:store_id` and `:now` for deterministic tests,
  and `:migrations_dir` to override the migration source.
  """
  @spec start(keyword()) ::
          {:ready, store()} | {:blocked, blocked_state(), Error.t()} | {:error, term()}
  def start(opts) do
    path = Keyword.fetch!(opts, :path)

    case Connection.integrity_precheck(path) do
      :ok -> open_and_continue(path, opts)
      {:error, error} -> {:blocked, :integrity_blocked, error}
    end
  end

  @doc """
  Supervised entry point: start a ready store or fail the child start.

  Returns `{:ok, conn}` when startup reaches `:ready`, exposing the supervised
  connection process, or `{:error, reason}` when startup is blocked or the
  connection is unavailable, so a supervisor does not treat a blocked store as
  healthy.
  """
  @spec start_link(keyword()) :: {:ok, Connection.conn()} | {:error, term()}
  def start_link(opts) do
    case start(opts) do
      {:ready, store} -> {:ok, store.conn}
      {:blocked, state, error} -> {:error, {state, error}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc false
  def child_spec(opts) do
    %{id: Keyword.get(opts, :name, __MODULE__), start: {__MODULE__, :start_link, [opts]}}
  end

  defp open_and_continue(path, opts) do
    connect_opts = [path: path] |> maybe_put(:name, Keyword.get(opts, :name))

    case Connection.start_link(connect_opts) do
      {:ok, conn} -> continue_or_stop(conn, opts)
      {:error, reason} -> {:error, reason}
    end
  end

  defp continue_or_stop(conn, opts) do
    case continue(conn, opts) do
      {:ready, _store} = ready ->
        ready

      blocked_or_error ->
        stop_connection(conn)
        blocked_or_error
    end
  rescue
    exception ->
      stop_connection(conn)
      reraise exception, __STACKTRACE__
  catch
    kind, reason ->
      stop_connection(conn)
      :erlang.raise(kind, reason, __STACKTRACE__)
  end

  @doc "The accepted store format identifier."
  @spec store_format() :: String.t()
  def store_format, do: @store_format

  @doc """
  The canonical Artifact root for a state file at `path`.

  The Artifact root is the deterministic `<state_dir>/artifacts` directory
  sibling of the SQLite state file. This is the same path the accepted
  startup sequence creates and verifies in `ensure_artifact_root/1`, so any
  caller that holds a `conn` (e.g. a CLI command after `Kiln.Store.start_link/1`)
  can recover the Artifact root without rebuilding the full startup map.

  This helper is the single source of truth for the path layout; it never
  touches the filesystem and never derives an alternative location.
  """
  @spec artifact_root_for_path(Path.t()) :: String.t()
  def artifact_root_for_path(path) when is_binary(path) do
    Path.join(Path.dirname(path), "artifacts")
  end

  @doc "Rebuild a Session projection from the journal (see `Kiln.Journal.Replay`)."
  defdelegate rebuild(conn, session_id), to: Kiln.Journal.Replay

  @doc "Reconstruct the current Session at startup (see `Kiln.Restart`)."
  defdelegate reconstruct(conn), to: Kiln.Restart

  defp continue(conn, opts) do
    with {:ok, info} <- verify(conn),
         {:ok, meta} <- ensure_metadata(conn, opts),
         {:ok, migration} <- run_migrations(conn, opts),
         :ok <- ensure_artifact_root(opts) do
      {:ready,
       %{
         conn: conn,
         store_id: meta.store_id,
         store_format: meta.store_format,
         store_version: migration.version,
         sqlite_version: info.sqlite_version,
         state_path: Keyword.fetch!(opts, :path),
         artifact_root: artifact_root(opts),
         info: info
       }}
    end
  end

  # Derive the Artifact root below the same Kiln home that owns the SQLite
  # store file. The state file's parent directory is the accepted Kiln home;
  # the Artifact root is the deterministic `artifacts/` directory inside it.
  # The root is created if absent and verified to be a real, non-symlink
  # directory before the store reaches `:ready` (P1-S02-T01-R01, R13).
  defp artifact_root(opts) do
    state_path = Keyword.fetch!(opts, :path)
    artifact_root_for_path(state_path)
  end

  defp ensure_artifact_root(opts) do
    root = artifact_root(opts)

    case Kiln.Artifact.FS.ensure_root(root) do
      :ok ->
        :ok

      {:error, error} ->
        {:blocked, :integrity_blocked, error}
    end
  end

  defp verify(conn) do
    case Connection.verify(conn) do
      {:ok, info} -> {:ok, info}
      {:error, error} -> {:blocked, :integrity_blocked, error}
    end
  end

  defp ensure_metadata(conn, opts) do
    Connection.query!(conn, """
    CREATE TABLE IF NOT EXISTS store_metadata (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      store_format TEXT NOT NULL,
      store_id TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
    """)

    case Connection.query!(conn, "SELECT store_format, store_id FROM store_metadata WHERE id = 1") do
      [] -> initialize_metadata(conn, opts)
      [[store_format, store_id]] -> validate_metadata(store_format, store_id)
    end
  end

  defp initialize_metadata(conn, opts) do
    store_id = Keyword.get(opts, :store_id, generate_store_id())
    now = Keyword.get(opts, :now, utc_now())

    Connection.query!(
      conn,
      "INSERT INTO store_metadata (id, store_format, store_id, created_at) VALUES (1, ?1, ?2, ?3)",
      [@store_format, store_id, now]
    )

    {:ok, %{store_format: @store_format, store_id: store_id}}
  end

  defp validate_metadata(store_format, store_id) when store_format in @supported_formats do
    {:ok, %{store_format: store_format, store_id: store_id}}
  end

  defp validate_metadata(store_format, _store_id) do
    {:blocked, :version_blocked,
     Error.new(
       :future_version,
       :unsupported_store_format,
       "store format is not supported by this binary",
       %{
         store_format: store_format,
         supported: @supported_formats
       }
     )}
  end

  defp run_migrations(conn, opts) do
    migrate_opts =
      opts
      |> Keyword.take([:now])
      |> maybe_put(:dir, Keyword.get(opts, :migrations_dir))

    case Migrations.migrate(conn, migrate_opts) do
      {:ok, result} -> {:ok, result}
      {:error, %Error{class: :future_version} = error} -> {:blocked, :version_blocked, error}
      {:error, %Error{} = error} -> {:blocked, :migration_blocked, error}
    end
  end

  defp stop_connection(conn) do
    if Process.alive?(conn) do
      GenServer.stop(conn, :normal, 5_000)
    end

    :ok
  catch
    :exit, _reason -> :ok
  end

  defp generate_store_id do
    "store_" <> (:crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower))
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp utc_now do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end
end
