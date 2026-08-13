defmodule Kiln.Store.MigrationsTest do
  use ExUnit.Case, async: true

  alias Kiln.Store.{Connection, Migrations}

  setup do
    dir = Path.join(System.tmp_dir!(), "kiln-mig-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)

    {:ok, conn} = Connection.start_link(path: Path.join(dir, "state.sqlite3"))
    on_exit(fn -> stop(conn) end)

    {:ok, conn: conn, dir: dir}
  end

  test "applies the initial migration on a fresh store", %{conn: conn} do
    assert {:ok, %{version: 5, applied_now: [1, 2, 3, 4, 5]}} =
             Migrations.migrate(conn, now: "2026-07-29T00:00:00Z")

    assert Migrations.current_version(conn) == 5

    tables =
      conn
      |> Connection.query!("SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name")
      |> List.flatten()

    assert "schema_migrations" in tables
    assert "journal_entries" in tables
    assert "action_commits" in tables
    assert "session_projections" in tables
    assert "transcript_records" in tables
  end

  test "records the file checksum for an applied migration", %{conn: conn} do
    {:ok, _} = Migrations.migrate(conn, now: "2026-07-29T00:00:00Z")
    {:ok, [_migration_1, migration_2 | _rest]} = Migrations.discover()

    rows =
      conn
      |> Connection.query!("SELECT version, checksum FROM schema_migrations ORDER BY version")
      |> Enum.map(&List.to_tuple/1)

    assert {2, checksum} = Enum.find(rows, &match?({2, _}, &1))
    assert checksum == migration_2.checksum
  end

  test "is idempotent when already current", %{conn: conn} do
    {:ok, _} = Migrations.migrate(conn, now: "2026-07-29T00:00:00Z")
    assert {:ok, %{version: 5, applied_now: []}} = Migrations.migrate(conn)
  end

  test "blocks when the bundled migration set is absent", %{conn: conn, dir: dir} do
    missing = Path.join(dir, "missing-migrations")

    assert {:error, %{class: :migration, code: :missing_migrations}} =
             Migrations.migrate(conn, dir: missing)

    assert Migrations.current_version(conn) == 0

    assert [] =
             Connection.query!(
               conn,
               "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'journal_entries'"
             )
  end

  test "blocks a modified applied migration", %{conn: conn} do
    {:ok, _} = Migrations.migrate(conn)

    Connection.query!(
      conn,
      "UPDATE schema_migrations SET checksum = 'deadbeef' WHERE version = 1"
    )

    assert {:error, %{class: :migration, code: :checksum_mismatch}} = Migrations.migrate(conn)
  end

  test "blocks a store written by a newer binary", %{conn: conn} do
    {:ok, _} = Migrations.migrate(conn)

    Connection.query!(
      conn,
      "INSERT INTO schema_migrations (version, name, checksum, applied_at) VALUES (9999, 'future', 'x', '2026-07-29T00:00:00Z')"
    )

    assert {:error, %{class: :future_version, code: :unknown_applied_migration}} =
             Migrations.migrate(conn)
  end

  describe "v1 to v2 upgrade safety (P1-S01-T06)" do
    test "a populated v1 store with distinct per-session idempotency_keys applies migration 2 cleanly",
         %{dir: dir} do
      v1 = build_v1_store(dir)

      insert_v1_action_commit(v1.conn, %{
        session_id: "ses_00000000000000000000000000000001",
        idempotency_key: "idem_00000000000000000000000000000001",
        request_digest: "sha256:01"
      })

      insert_v1_action_commit(v1.conn, %{
        session_id: "ses_00000000000000000000000000000002",
        idempotency_key: "idem_00000000000000000000000000000002",
        request_digest: "sha256:02"
      })

      assert {:ok, %{version: 5, applied_now: [2, 3, 4, 5]}} =
               Migrations.migrate(v1.conn, now: "2026-08-01T00:00:00Z")

      assert Migrations.current_version(v1.conn) == 5

      idx_rows =
        Connection.query!(
          v1.conn,
          "SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'action_commits_idempotency_key_idx'"
        )

      assert idx_rows != [],
             "the v2 upgrade must create the global idempotency_key unique index"
    end

    test "a populated v1 store with cross-session duplicate idempotency_keys rejects migration 2 with structured details",
         %{dir: dir} do
      v1 = build_v1_store(dir)

      insert_v1_action_commit(v1.conn, %{
        session_id: "ses_00000000000000000000000000000001",
        idempotency_key: "idem_0000000000000000000000000000000a",
        request_digest: "sha256:01"
      })

      insert_v1_action_commit(v1.conn, %{
        session_id: "ses_00000000000000000000000000000002",
        idempotency_key: "idem_0000000000000000000000000000000a",
        request_digest: "sha256:02"
      })

      assert {:error,
              %{
                class: :migration,
                code: :duplicate_global_idempotency_keys,
                details: %{
                  duplicates: [
                    %{
                      idempotency_key: "idem_0000000000000000000000000000000a",
                      session_ids: session_ids
                    }
                  ]
                }
              }} = Migrations.migrate(v1.conn, now: "2026-08-01T00:00:00Z")

      assert Enum.sort(session_ids) == [
               "ses_00000000000000000000000000000001",
               "ses_00000000000000000000000000000002"
             ]

      assert Migrations.current_version(v1.conn) == 1,
             "a failed v2 upgrade must not advance the state migration version"

      idx_rows =
        Connection.query!(
          v1.conn,
          "SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'action_commits_idempotency_key_idx'"
        )

      assert idx_rows == [],
             "a failed v2 upgrade must not leave the global index in place"
    end

    test "a populated v1 store with cross-session duplicate idempotency_keys remains at v1 and accepts further v1 writes",
         %{dir: dir} do
      v1 = build_v1_store(dir)

      insert_v1_action_commit(v1.conn, %{
        session_id: "ses_00000000000000000000000000000001",
        idempotency_key: "idem_0000000000000000000000000000000b",
        request_digest: "sha256:01"
      })

      insert_v1_action_commit(v1.conn, %{
        session_id: "ses_00000000000000000000000000000002",
        idempotency_key: "idem_0000000000000000000000000000000b",
        request_digest: "sha256:02"
      })

      {:error, %{class: :migration, code: :duplicate_global_idempotency_keys}} =
        Migrations.migrate(v1.conn, now: "2026-08-01T00:00:00Z")

      insert_v1_action_commit(v1.conn, %{
        session_id: "ses_00000000000000000000000000000003",
        idempotency_key: "idem_0000000000000000000000000000000b",
        request_digest: "sha256:03"
      })

      assert count_action_commits(v1.conn) == 3
      assert Migrations.current_version(v1.conn) == 1
    end

    test "a valid v1 store with distinct per-session idempotency_keys upgrades and remains replayable",
         %{dir: dir} do
      v1 = build_v1_store(dir)
      alias Kiln.Journal.Replay

      session_one = "ses_00000000000000000000000000000001"
      session_two = "ses_00000000000000000000000000000002"

      seed_v1_session!(v1.conn, session_one, "idem_0000000000000000000000000000000c", 1)
      seed_v1_session!(v1.conn, session_two, "idem_0000000000000000000000000000000d", 2)

      # Before the upgrade the rebuild must already succeed.
      assert {:ok, report_one} = Replay.rebuild(v1.conn, session_one)
      assert report_one.projection["session"]["id"] == session_one

      assert {:ok, report_two} = Replay.rebuild(v1.conn, session_two)
      assert report_two.projection["session"]["id"] == session_two

      assert {:ok, %{version: 5, applied_now: [2, 3, 4, 5]}} =
               Migrations.migrate(v1.conn, now: "2026-08-01T00:00:00Z")

      # After the upgrade the rebuild must still succeed; this is the
      # post-upgrade replay contract the durable migration promises.
      assert {:ok, report_one_after} = Replay.rebuild(v1.conn, session_one)
      assert report_one_after.projection["session"]["id"] == session_one
      assert report_one_after.projection_digest == report_one.projection_digest

      assert {:ok, report_two_after} = Replay.rebuild(v1.conn, session_two)
      assert report_two_after.projection["session"]["id"] == session_two
      assert report_two_after.projection_digest == report_two.projection_digest
    end
  end

  # Build a v1-only store by applying just migration 1's SQL directly and
  # recording it in `schema_migrations` so the upgrade runner sees the v1
  # baseline and only attempts the v2 step. This simulates the on-disk shape
  # a v1 binary would have written before the v2 migration was bundled.
  defp build_v1_store(dir) do
    path = Path.join(dir, "v1-state-#{System.unique_integer([:positive])}.sqlite3")
    {:ok, conn} = Connection.start_link(path: path)
    apply_first_migration(conn)
    record_v1_application(conn)
    on_exit(fn -> stop(conn) end)
    %{conn: conn, path: path}
  end

  defp apply_first_migration(conn) do
    sql =
      File.read!(
        Application.app_dir(:kiln, ["priv", "store", "migrations", "0001_initial_state.sql"])
      )

    Enum.each(split_statements(sql), &Connection.query!(conn, &1))
    conn
  end

  defp record_v1_application(conn) do
    Connection.query!(
      conn,
      """
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        checksum TEXT NOT NULL,
        applied_at TEXT NOT NULL
      )
      """
    )

    {:ok, migrations} = Migrations.discover()

    [v1 | _] = Enum.sort_by(migrations, & &1.version)

    Connection.query!(
      conn,
      "INSERT INTO schema_migrations (version, name, checksum, applied_at) VALUES (1, ?1, ?2, '2026-07-29T00:00:00Z')",
      [v1.name, v1.checksum]
    )
  end

  defp strip_line_comments(sql) do
    sql
    |> String.split("\n")
    |> Enum.map(fn line ->
      case :binary.match(line, "--") do
        {index, _} -> binary_part(line, 0, index)
        :nomatch -> line
      end
    end)
    |> Enum.join("\n")
  end

  defp split_statements(sql) do
    sql
    |> strip_line_comments()
    |> String.split(";")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp insert_v1_action_commit(conn, spec) do
    session_suffix = binary_part(spec.session_id, byte_size(spec.session_id) - 2, 2)
    idem_suffix = binary_part(spec.idempotency_key, byte_size(spec.idempotency_key) - 2, 2)
    suffix = session_suffix <> idem_suffix

    Connection.query!(
      conn,
      """
      INSERT INTO action_commits
        (action_id, session_id, idempotency_key, request_digest, expected_session_revision,
         first_sequence, last_sequence, result_schema, result, result_digest, committed_at)
      VALUES (?1, ?2, ?3, ?4, 0, 1, 1, 'action_result/v1', '{}', 'x', '2026-07-29T00:00:00Z')
      """,
      [
        "act_0000000000000000000000000000" <> suffix,
        spec.session_id,
        spec.idempotency_key,
        spec.request_digest
      ]
    )
  end

  defp count_action_commits(conn) do
    [[n]] = Connection.query!(conn, "SELECT count(*) FROM action_commits")
    n
  end

  # Plant a minimal but valid v1 session: one journal entry
  # (session_started/v1) and one action_commit with the given idempotency
  # key and a request digest that matches the entry payload. The session
  # id, task id, run id, action id, and idempotency key are all
  # well-formed opaque identifiers; the request digest is a real
  # canonical digest of the entry payload, so `Replay.rebuild/2` accepts
  # it before and after the v2 upgrade.
  defp seed_v1_session!(conn, session_id, idempotency_key, first_sequence) do
    # Derive per-session opaque identifiers from the session_id tail so the
    # two seeded sessions get distinct action_id, task_id, run_id, and
    # root_run_id values without any randomness that would invalidate the
    # fixture on retry. Each tail is 8 hex chars; we pad to 32 hex chars
    # so the resulting identifier matches the opaque-identifier shape
    # (`<prefix>_<32 lowercase hex>`).
    # Pad the 8-hex tail to 32 hex chars by repeating it four times. Each
    # session_id has a distinct 8-hex tail (00000001 vs 00000002) so the
    # resulting identifiers are distinct and valid opaque Kiln ids.
    tail = String.slice(session_id, -8..-1)
    hex32 = String.duplicate(tail, 4)
    task_id = "tsk_" <> hex32
    run_id = "run_" <> hex32
    action_id = "act_" <> hex32
    # The reducer requires `run.root_run_id == run.id` for the first action
    # (no parent run to inherit from). Using the same identifier for both
    # satisfies the invariant without inventing new fake IDs.
    root_run_id = run_id

    payload = %{
      "session" => %{"id" => session_id, "state" => "active"},
      "task" => %{"id" => task_id, "state" => "in_progress"},
      "run" => %{"id" => run_id, "state" => "ready", "root_run_id" => root_run_id},
      "workflow_step" => "intent",
      "objective" => "valid v1 fixture",
      "criteria" => ["The focused test passes"],
      "constraints" => [],
      "exclusions" => [],
      "objective_revision" => 0,
      "criteria_revision" => 0,
      "references" => %{}
    }

    payload_schema = "session_started/v1"
    payload_text = Kiln.Store.Canonical.encode(payload)
    payload_digest = Kiln.Store.Canonical.digest(payload_schema, payload)
    request_digest = "sha256:" <> payload_digest

    Connection.query!(
      conn,
      """
      INSERT INTO journal_entries
        (entry_id, entry_schema, entry_type, payload_schema, session_id, session_revision,
         action_id, actor_kind, actor_id, idempotency_key, request_digest,
         causation_entry_id, correlation_id, recorded_at, sequence, payload, payload_digest)
      VALUES (?1, 'journal_entry/v1', 'session_started/v1', ?8, ?2, 0,
              ?3, 'local_user', 'user:local', ?4, ?5, NULL, NULL, '2026-07-29T00:00:00Z', ?9, ?6, ?7)
      """,
      [
        Kiln.Store.Uuid.v7(),
        session_id,
        action_id,
        idempotency_key,
        request_digest,
        payload_text,
        payload_digest,
        payload_schema,
        first_sequence
      ]
    )

    result_map = %{
      session_id: session_id,
      task_id: task_id,
      run_id: run_id,
      action_id: action_id,
      session_revision: 0,
      run_state: "ready",
      projection_digest: "sha256:" <> String.duplicate("0", 64)
    }

    result_schema = "action_result/v1"
    result_text = Kiln.Store.Canonical.encode(result_map)
    result_digest = Kiln.Store.Canonical.digest(result_schema, result_map)

    Connection.query!(
      conn,
      """
      INSERT INTO action_commits
        (action_id, session_id, idempotency_key, request_digest, expected_session_revision,
         first_sequence, last_sequence, result_schema, result, result_digest, committed_at)
      VALUES (?1, ?2, ?3, ?4, 0, ?7, ?7, 'action_result/v1', ?5, ?6, '2026-07-29T00:00:00Z')
      """,
      [
        action_id,
        session_id,
        idempotency_key,
        request_digest,
        result_text,
        result_digest,
        first_sequence
      ]
    )

    :ok
  end

  describe "compound statements (P1-S02-T01-R16, AC15)" do
    test "migration 0004 creates the aggregate-limit trigger", %{conn: conn} do
      {:ok, _} = Migrations.migrate(conn, now: "2026-08-11T00:00:00Z")

      assert [["evidence_warnings_aggregate_limit"]] =
               Connection.query!(
                 conn,
                 "SELECT name FROM sqlite_master WHERE type = 'trigger' ORDER BY name"
               )
    end

    test "exactly 16,384 aggregate warning bytes commit and 16,385 aborts", %{conn: conn} do
      {:ok, _} = Migrations.migrate(conn, now: "2026-08-11T00:00:00Z")
      evidence_id = seed_evidence!(conn)

      # 16 items x 1,024 bytes is exactly the accepted maximum.
      Enum.each(0..15, fn position ->
        insert_warning!(conn, evidence_id, position, 1024)
      end)

      assert aggregate_warning_bytes(conn, evidence_id) == 16_384

      assert_raise Exqlite.Error, fn ->
        insert_warning!(conn, evidence_id, 16, 1)
      end

      # The aborted statement left the aggregate untouched.
      assert aggregate_warning_bytes(conn, evidence_id) == 16_384
      assert count_warnings(conn, evidence_id) == 16
    end

    test "a single warning over 1,024 bytes is rejected by its row CHECK", %{conn: conn} do
      {:ok, _} = Migrations.migrate(conn, now: "2026-08-11T00:00:00Z")
      evidence_id = seed_evidence!(conn)

      assert_raise Exqlite.Error, fn ->
        insert_warning!(conn, evidence_id, 0, 1025)
      end

      assert count_warnings(conn, evidence_id) == 0
    end

    test "warning position is bounded to 0 through 63", %{conn: conn} do
      {:ok, _} = Migrations.migrate(conn, now: "2026-08-11T00:00:00Z")
      evidence_id = seed_evidence!(conn)

      assert_raise Exqlite.Error, fn -> insert_warning!(conn, evidence_id, 64, 1) end
      assert_raise Exqlite.Error, fn -> insert_warning!(conn, evidence_id, -1, 1) end
      assert count_warnings(conn, evidence_id) == 0
    end

    test "non-compound SQL splits byte-for-byte as the pre-R16 splitter did", %{conn: conn} do
      {:ok, migrations} = Migrations.discover()

      # Direct observable comparison against the pre-R16 reference splitter.
      # Absence of CREATE TRIGGER alone would not prove equivalence if the
      # splitter had been globally rewritten, so compare actual output.
      for migration <- migrations, migration.version <= 3 do
        assert Migrations.__statements__(migration.sql) ==
                 pre_r16_split_statements(migration.sql),
               "migration #{migration.version} statement sequence changed under R16"
      end

      # Only 0004 introduces a compound statement, and it must survive whole.
      trigger_versions =
        migrations
        |> Enum.filter(&String.contains?(String.upcase(&1.sql), "CREATE TRIGGER"))
        |> Enum.map(& &1.version)

      assert trigger_versions == [4]

      compound =
        migrations
        |> Enum.find(&(&1.version == 4))
        |> then(& &1.sql)
        |> Migrations.__statements__()
        |> Enum.filter(&String.contains?(String.upcase(&1), "CREATE TRIGGER"))

      assert [trigger_statement] = compound
      assert String.contains?(trigger_statement, "BEGIN")
      assert String.contains?(trigger_statement, "RAISE(ABORT")
      assert String.ends_with?(String.trim(trigger_statement), "END")

      # The naive splitter would have shredded that same statement.
      shredded =
        migrations
        |> Enum.find(&(&1.version == 4))
        |> then(& &1.sql)
        |> pre_r16_split_statements()
        |> Enum.filter(&String.contains?(String.upcase(&1), "CREATE TRIGGER"))

      assert [fragment] = shredded
      refute String.ends_with?(String.trim(fragment), "END")

      assert {:ok, %{version: 5}} = Migrations.migrate(conn, now: "2026-08-11T00:00:00Z")
    end

    test "recorded checksums stay bound to file bytes, not the split", %{conn: conn} do
      {:ok, migrations} = Migrations.discover()
      {:ok, _} = Migrations.migrate(conn, now: "2026-08-11T00:00:00Z")

      applied = Migrations.applied(conn)

      for migration <- migrations do
        assert applied[migration.version] == migration.checksum
        assert migration.checksum == sha256_hex(migration.sql)
      end
    end

    test "an unterminated compound statement fails and records no checksum", %{
      conn: conn,
      dir: dir
    } do
      custom = Path.join(dir, "migrations")
      File.mkdir_p!(custom)

      File.write!(Path.join(custom, "0001_broken_trigger.sql"), """
      CREATE TABLE probe (id INTEGER PRIMARY KEY, value TEXT);
      CREATE TRIGGER probe_guard BEFORE INSERT ON probe
      BEGIN
        SELECT RAISE(ABORT, 'never') WHERE 1 = 0;
      """)

      assert {:error, %{class: :migration, code: :apply_failed}} =
               Migrations.migrate(conn, dir: custom, now: "2026-08-11T00:00:00Z")

      assert Migrations.applied(conn) == %{}

      tables =
        conn
        |> Connection.query!("SELECT name FROM sqlite_master WHERE type = 'table'")
        |> List.flatten()

      refute "probe" in tables
    end
  end

  defp seed_evidence!(conn) do
    artifact_id = "01890a5d-ac96-774b-bcce-b302099a8057"
    evidence_id = "01890a5d-ac96-774b-bcce-b302099a8058"

    Connection.query!(conn, """
    INSERT INTO artifacts VALUES (
      '#{artifact_id}','s','r',NULL,'run','o','command','p','output','text/plain','utf_8',
      'sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      11,'sha256/e3/b0c44',NULL,NULL,'kiln_generated','project','run','complete',
      '2026-08-11T00:00:00Z','kiln.artifact/v1','idem-a',
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa')
    """)

    Connection.query!(conn, """
    INSERT INTO evidence_records VALUES (
      '#{evidence_id}','s','r','crit-1','rev-1','subj-1','run','sd',
      'repository','p','repository_observation','pass','rsd',
      NULL,NULL,NULL,NULL,NULL,NULL,'ed','od','complete','same_repository_state',
      '2026-08-11T00:00:00Z','2026-08-11T00:00:00Z',NULL,'kiln.evidence/v1','idem-e',
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc')
    """)

    evidence_id
  end

  defp insert_warning!(conn, evidence_id, position, bytes) do
    Connection.query!(conn, "INSERT INTO evidence_warnings VALUES (?1, ?2, ?3)", [
      evidence_id,
      position,
      String.duplicate("x", bytes)
    ])
  end

  defp aggregate_warning_bytes(conn, evidence_id) do
    [[total]] =
      Connection.query!(
        conn,
        "SELECT COALESCE(SUM(length(CAST(warning AS BLOB))), 0) FROM evidence_warnings WHERE evidence_id = ?1",
        [evidence_id]
      )

    total
  end

  defp count_warnings(conn, evidence_id) do
    [[count]] =
      Connection.query!(
        conn,
        "SELECT count(*) FROM evidence_warnings WHERE evidence_id = ?1",
        [evidence_id]
      )

    count
  end

  # The exact pre-R16 splitter, retained as the reference behavior that
  # non-compound migrations must continue to produce byte-for-byte.
  defp pre_r16_split_statements(sql) do
    sql
    |> String.split("\n")
    |> Enum.map(fn line ->
      case :binary.match(line, "--") do
        {index, _} -> binary_part(line, 0, index)
        :nomatch -> line
      end
    end)
    |> Enum.join("\n")
    |> String.split(";")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp sha256_hex(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)

  defp stop(conn) do
    if Process.alive?(conn), do: GenServer.stop(conn)
    :ok
  catch
    :exit, _reason -> :ok
  end
end
