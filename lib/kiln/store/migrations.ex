defmodule Kiln.Store.Migrations do
  @moduledoc """
  Kiln-owned forward SQL migrations for the state store.

  Migrations live under `priv/store/migrations` as `NNNN_name.sql`. Each file
  has one stable SHA-256 checksum; an applied checksum is immutable. This runner
  owns the `schema_migrations` bookkeeping table, detects a store written by a
  newer binary, rejects a modified applied migration, and applies each pending
  migration inside its own `BEGIN IMMEDIATE` transaction so a failed statement
  records no version (P1-S01-T02-R07, R08).
  """

  alias Kiln.Store.{Connection, Error}

  @typedoc "One discovered migration file."
  @type migration :: %{
          version: non_neg_integer(),
          name: String.t(),
          filename: String.t(),
          sql: String.t(),
          checksum: String.t()
        }

  @doc "Absolute path to the bundled migrations directory."
  @spec default_dir() :: String.t()
  def default_dir do
    Application.app_dir(:kiln, ["priv", "store", "migrations"])
  end

  @doc """
  Discover migration files under `dir`, ordered by version.

  Returns `{:error, ...}` when no migration bundle exists, a filename is
  malformed, or a version repeats. A binary without its bundled migrations must
  never expose a fresh version-zero store as ready.
  """
  @spec discover(String.t()) :: {:ok, [migration()]} | {:error, Error.t()}
  def discover(dir \\ default_dir()) do
    dir
    |> Path.join("*.sql")
    |> Path.wildcard()
    |> Enum.sort()
    |> Enum.reduce_while({:ok, []}, fn path, {:ok, acc} ->
      case parse_file(path) do
        {:ok, migration} -> {:cont, {:ok, [migration | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, migrations} ->
        migrations
        |> Enum.reverse()
        |> ensure_unique_versions()
        |> ensure_present()

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Bring `conn` to the latest known schema version.

  Returns `{:ok, %{version: v, applied_now: [...]}}` on success, or a classified
  `Kiln.Store.Error`:

    * `:future_version` when the store has an applied version this binary does
      not know (startup `version_blocked`);
    * `:migration` when the migration bundle is missing, an applied checksum
      differs, or a migration statement fails (startup `migration_blocked`);
    * `:duplicate_global_idempotency_keys` when migration 2 would fail because
      the v1 store contains two `action_commits` rows with the same
      `idempotency_key` under different `session_id`s. The error lists the
      offending keys and affected sessions.

  `opts[:dir]` overrides the migrations directory; `opts[:now]` supplies the
  applied timestamp as an ISO 8601 string.
  """
  @spec migrate(Connection.conn(), keyword()) ::
          {:ok, %{version: non_neg_integer(), applied_now: [non_neg_integer()]}}
          | {:error, Error.t()}
  def migrate(conn, opts \\ []) do
    dir = Keyword.get(opts, :dir, default_dir())
    now = Keyword.get(opts, :now, utc_now())

    with :ok <- ensure_bookkeeping(conn),
         {:ok, migrations} <- discover(dir),
         applied <- applied(conn),
         :ok <- reject_future(migrations, applied),
         :ok <- reject_modified(migrations, applied),
         :ok <- reject_duplicate_idempotency_keys(conn, migrations, applied) do
      apply_pending(conn, migrations, applied, now)
    end
  end

  @doc "Applied migrations as a map of version to checksum."
  @spec applied(Connection.conn()) :: %{non_neg_integer() => String.t()}
  def applied(conn) do
    conn
    |> Connection.query!("SELECT version, checksum FROM schema_migrations ORDER BY version")
    |> Map.new(fn [version, checksum] -> {version, checksum} end)
  end

  @doc "Highest applied migration version, or 0 when none are applied."
  @spec current_version(Connection.conn()) :: non_neg_integer()
  def current_version(conn) do
    conn
    |> applied()
    |> Map.keys()
    |> Enum.max(fn -> 0 end)
  end

  # -- internals --

  defp ensure_bookkeeping(conn) do
    Connection.query!(conn, """
    CREATE TABLE IF NOT EXISTS schema_migrations (
      version INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      checksum TEXT NOT NULL,
      applied_at TEXT NOT NULL
    )
    """)

    :ok
  end

  defp reject_future(migrations, applied) do
    known = MapSet.new(migrations, & &1.version)

    case Enum.find(Map.keys(applied), fn version -> not MapSet.member?(known, version) end) do
      nil ->
        :ok

      version ->
        {:error,
         Error.new(
           :future_version,
           :unknown_applied_migration,
           "store has a migration this binary does not know",
           %{
             applied_version: version
           }
         )}
    end
  end

  defp reject_modified(migrations, applied) do
    migrations
    |> Enum.filter(fn migration -> Map.has_key?(applied, migration.version) end)
    |> Enum.find(fn migration -> applied[migration.version] != migration.checksum end)
    |> case do
      nil ->
        :ok

      migration ->
        {:error,
         Error.new(:migration, :checksum_mismatch, "an applied migration has been modified", %{
           version: migration.version,
           filename: migration.filename
         })}
    end
  end

  # Migration 0002 introduces the global `UNIQUE INDEX
  # action_commits_idempotency_key_idx`. The v1 schema permitted duplicate
  # `idempotency_key` values across `session_id`s because uniqueness was only
  # `(session_id, idempotency_key)`. Pre-detect those duplicates with a
  # read-only aggregate query so we can return a specific structured error
  # and avoid opening the migration transaction at all. The check only
  # runs when migration 2 is actually pending AND the `action_commits` table
  # already exists; an already-upgraded store or a fresh-store first migration
  # skips the query entirely.
  defp reject_duplicate_idempotency_keys(conn, migrations, applied) do
    if migration_pending?(2, migrations, applied) and action_commits_table_exists?(conn) do
      duplicates = find_duplicate_idempotency_keys(conn)

      case duplicates do
        [] ->
          :ok

        _ ->
          {:error,
           Error.new(
             :migration,
             :duplicate_global_idempotency_keys,
             "v1 store contains action_commits rows with cross-session duplicate idempotency_keys; resolve before upgrading",
             %{duplicates: duplicates}
           )}
      end
    else
      :ok
    end
  end

  defp action_commits_table_exists?(conn) do
    rows =
      Connection.query!(
        conn,
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'action_commits'"
      )

    rows != []
  end

  defp migration_pending?(version, migrations, applied) do
    Map.has_key?(migrations_by_version(migrations), version) and
      not Map.has_key?(applied, version)
  end

  defp migrations_by_version(migrations), do: Map.new(migrations, &{&1.version, &1})

  # Returns a list of `%{idempotency_key: String.t(), session_ids: [String.t()]}`
  # for every `idempotency_key` that appears under more than one
  # `session_id`. The list is bounded by the actual duplicate count in the
  # store; a deterministic scan over `action_commits` keeps the cost O(N)
  # for the rows that exist rather than materializing a hypothetical range.
  defp find_duplicate_idempotency_keys(conn) do
    rows =
      Connection.query!(
        conn,
        """
        SELECT idempotency_key, GROUP_CONCAT(session_id, ',') AS session_ids
        FROM action_commits
        GROUP BY idempotency_key
        HAVING COUNT(DISTINCT session_id) > 1
        ORDER BY idempotency_key
        """
      )

    Enum.map(rows, fn [idempotency_key, session_ids_csv] ->
      %{
        idempotency_key: idempotency_key,
        session_ids: String.split(session_ids_csv, ",")
      }
    end)
  end

  defp apply_pending(conn, migrations, applied, now) do
    pending =
      Enum.reject(migrations, fn migration -> Map.has_key?(applied, migration.version) end)

    Enum.reduce_while(pending, {:ok, []}, fn migration, {:ok, done} ->
      case apply_one(conn, migration, now) do
        :ok -> {:cont, {:ok, [migration.version | done]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, applied_now} ->
        {:ok, %{version: current_version(conn), applied_now: Enum.reverse(applied_now)}}

      {:error, _} = error ->
        error
    end
  end

  defp apply_one(conn, migration, now) do
    result =
      Connection.transaction(conn, fn tx ->
        Enum.each(statements(migration.sql), fn statement ->
          Connection.query!(tx, statement)
        end)

        Connection.query!(
          tx,
          "INSERT INTO schema_migrations (version, name, checksum, applied_at) VALUES (?1, ?2, ?3, ?4)",
          [migration.version, migration.name, migration.checksum, now]
        )
      end)

    case result do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        {:error,
         Error.new(:migration, :apply_failed, "a migration statement failed", %{
           version: migration.version,
           filename: migration.filename,
           reason: inspect(reason)
         })}
    end
  rescue
    exception ->
      {:error,
       Error.new(:migration, :apply_failed, "a migration statement failed", %{
         version: migration.version,
         filename: migration.filename,
         reason: Exception.message(exception)
       })}
  end

  defp parse_file(path) do
    filename = Path.basename(path)

    case Regex.run(~r/^(\d{4})_([a-z0-9_]+)\.sql$/, filename) do
      [_, version, name] ->
        sql = File.read!(path)

        {:ok,
         %{
           version: String.to_integer(version),
           name: name,
           filename: filename,
           sql: sql,
           checksum: :crypto.hash(:sha256, sql) |> Base.encode16(case: :lower)
         }}

      _ ->
        {:error,
         Error.new(:migration, :bad_filename, "migration filename is malformed", %{
           filename: filename
         })}
    end
  end

  defp ensure_unique_versions(migrations) do
    duplicate =
      migrations
      |> Enum.frequencies_by(& &1.version)
      |> Enum.find(fn {_version, count} -> count > 1 end)

    case duplicate do
      nil ->
        {:ok, migrations}

      {version, _} ->
        {:error,
         Error.new(:migration, :duplicate_version, "two migrations share a version", %{
           version: version
         })}
    end
  end

  defp ensure_present({:ok, []}) do
    {:error,
     Error.new(:migration, :missing_migrations, "the bundled migration set is missing", %{})}
  end

  defp ensure_present(result), do: result

  # Split a migration file into individual statements. Line comments are
  # stripped; statements are separated by semicolons. Migration SQL must not
  # embed semicolons inside string or identifier literals.
  #
  # A compound statement (`CREATE TRIGGER ... BEGIN ...; ...; END;`) contains
  # semicolons that terminate the statements inside its body, so naive
  # splitting shreds it into fragments that SQLite rejects with
  # "incomplete input". `rejoin_compound/1` reassembles those fragments into
  # one statement (P1-S02-T01-R16).
  #
  # A file containing no `CREATE TRIGGER` never enters the accumulating branch,
  # so migrations 0001 through 0003 produce a byte-identical statement
  # sequence and their recorded checksums are unaffected.
  @doc false
  # Test seam. `statements/1` is private, but P1-S02-T01-AC15 requires an
  # observable comparison proving the split of non-compound SQL is unchanged
  # by compound support rather than merely argued from the absence of
  # `CREATE TRIGGER`. Not part of the public Store API.
  @spec __statements__(String.t()) :: [String.t()]
  def __statements__(sql), do: statements(sql)

  defp statements(sql) do
    sql
    |> String.split("\n")
    |> Enum.map(&strip_line_comment/1)
    |> Enum.join("\n")
    |> String.split(";")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> rejoin_compound()
  end

  # Reassemble compound-statement bodies. Fragments are accumulated from the
  # one that opens a trigger until the one that closes it with `END`. The
  # separating semicolons are restored so the body reaches SQLite intact.
  #
  # An unterminated compound statement is emitted as-is rather than silently
  # dropped, so the driver reports the malformed SQL and the migration fails
  # without recording its checksum.
  defp rejoin_compound(fragments) do
    {reversed, pending} = Enum.reduce(fragments, {[], nil}, &accumulate_fragment/2)

    case pending do
      nil -> Enum.reverse(reversed)
      unterminated -> Enum.reverse([unterminated | reversed])
    end
  end

  defp accumulate_fragment(fragment, {done, nil}) do
    if compound_start?(fragment) do
      {done, fragment}
    else
      {[fragment | done], nil}
    end
  end

  defp accumulate_fragment(fragment, {done, buffer}) do
    combined = buffer <> ";\n" <> fragment

    if compound_end?(fragment) do
      {[combined | done], nil}
    else
      {done, combined}
    end
  end

  defp compound_start?(fragment), do: Regex.match?(~r/\bCREATE\s+TRIGGER\b/i, fragment)

  defp compound_end?(fragment), do: Regex.match?(~r/(\A|\s)END\z/i, String.trim(fragment))

  defp strip_line_comment(line) do
    case :binary.match(line, "--") do
      {index, _} -> binary_part(line, 0, index)
      :nomatch -> line
    end
  end

  defp utc_now do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end
end
