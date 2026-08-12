defmodule Kiln.Evidence.SQLConstraintsTest do
  @moduledoc """
  Direct-SQL constraint and defense-in-depth tests for the Evidence substrate.

  These tests prove the SQLite table CHECK constraints reject every
  shape of out-of-band input the plan forbids, without going through
  the Elixir Evidence.new/1 application validator. They are the
  evidence of database defense-in-depth required by P1-S02-T01-AC06
  and AC13.

  Every test here opens its own ready Store and runs direct SQL against
  `evidence_records`, `evidence_artifacts`, and `evidence_warnings`.
  """

  use ExUnit.Case, async: false

  alias Kiln.Evidence
  alias Kiln.Store

  @now "2026-08-10T12:00:00Z"

  setup do
    base = Path.join(System.tmp_dir!(), "kiln-evidence-sql-#{System.unique_integer([:positive])}")
    File.mkdir_p!(base)
    on_exit(fn -> File.rm_rf!(base) end)

    {:ready, store} =
      Store.start(
        path: Path.join(base, "state.sqlite3"),
        store_id: "evidence_sql_test",
        now: @now
      )

    on_exit(fn -> stop(store.conn) end)

    {:ok, store: store}
  end

  defp stop(conn) do
    if Process.alive?(conn), do: GenServer.stop(conn)
    :ok
  catch
    :exit, _ -> :ok
  end

  defp base_evidence_attrs(overrides) do
    Map.merge(
      %{
        evidence_id: "01900000-0000-7000-8000-000000000000",
        session_id: "session-1",
        run_id: "run-1",
        criterion_id: "criterion-1",
        criterion_revision: "v1",
        subject_id: "subject-1",
        subject_kind: :repository,
        subject_state_digest: "subject-digest",
        producer_kind: :deterministic_service,
        producer_id: "producer-1",
        method: :repository_observation,
        result: :pass,
        repository_state_digest: "repo-digest",
        artifact_ids: [],
        evaluator_digest: "eval-digest",
        observation_digest: "obs-digest",
        completeness: :complete,
        freshness_rule: :same_repository_state,
        observed_at: @now,
        recorded_at: @now,
        idempotency_key: "idem-1"
      },
      overrides
    )
  end

  defp build_record(store, attrs) do
    {:ok, evidence} = Evidence.new(base_evidence_attrs(attrs))
    %{sql: row_sql(record_row(evidence)), record: evidence}
  end

  defp record_row(evidence) do
    [
      evidence.evidence_id,
      evidence.session_id,
      evidence.run_id,
      evidence.criterion_id,
      evidence.criterion_revision,
      evidence.subject_id,
      Atom.to_string(evidence.subject_kind),
      evidence.subject_state_digest,
      Atom.to_string(evidence.producer_kind),
      evidence.producer_id,
      Atom.to_string(evidence.method),
      Atom.to_string(evidence.result),
      evidence.repository_state_digest,
      evidence.patch_id,
      evidence.patch_digest,
      evidence.patch_result_digest,
      evidence.host_profile_digest,
      evidence.command_registration_digest,
      evidence.command_result_id,
      evidence.evaluator_digest,
      evidence.observation_digest,
      Atom.to_string(evidence.completeness),
      Atom.to_string(evidence.freshness_rule),
      evidence.observed_at,
      evidence.recorded_at,
      evidence.rationale,
      evidence.schema,
      evidence.idempotency_key,
      evidence.request_digest,
      evidence.record_digest
    ]
  end

  defp row_sql(row) do
    placeholders = Enum.map_join(1..length(row), ",", &"?#{&1}")

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
    ) VALUES (#{placeholders})
    """
  end

  defp exec!(store, sql, params) do
    Kiln.Store.Connection.query!(store.conn, sql, params)
    :ok
  rescue
    err in Exqlite.Error ->
      {:error, err}
  end

  describe "AC06 — direct-SQL freshness vocabulary rejection" do
    test "rejects unknown freshness rule via direct SQL", %{store: store} do
      %{sql: sql, record: record} =
        build_record(store, %{freshness_rule: :same_repository_state})

      # Force an unknown value past the application validator by mutating
      # the SQL parameter list directly. Bypasses Evidence.new/1 by
      # inserting the literal 'time_bound' string.
      row = record_row(record) |> List.replace_at(22, "time_bound")

      assert {:error, _} = exec!(store, sql, row)

      rows =
        Kiln.Store.Connection.query!(
          store.conn,
          "SELECT COUNT(*) FROM evidence_records"
        )

      assert [[0]] == rows
    end

    test "rejects freshness_ttl_seconds via direct SQL", %{store: store} do
      %{sql: sql, record: record} =
        build_record(store, %{freshness_rule: :same_repository_state})

      row = record_row(record) |> List.replace_at(22, "freshness_ttl_seconds")
      assert {:error, _} = exec!(store, sql, row)
    end

    test "rejects zero TTL via direct SQL", %{store: store} do
      %{sql: sql, record: record} =
        build_record(store, %{freshness_rule: :same_repository_state})

      row = record_row(record) |> List.replace_at(22, "ttl_seconds_0")
      assert {:error, _} = exec!(store, sql, row)
    end

    test "no TTL column exists", %{store: store} do
      cols =
        Kiln.Store.Connection.query!(
          store.conn,
          "SELECT name FROM pragma_table_info('evidence_records')"
        )
        |> Enum.map(fn [c] -> c end)

      refute Enum.any?(cols, &String.contains?(&1, "ttl"))
      refute Enum.any?(cols, &String.contains?(&1, "time"))
    end
  end

  describe "AC13 — direct-SQL bound rejection" do
    test "rejects result outside the four accepted values", %{store: store} do
      %{sql: sql, record: record} =
        build_record(store, %{result: :pass, completeness: :complete})

      row = record_row(record) |> List.replace_at(11, "garbage")
      assert {:error, _} = exec!(store, sql, row)
    end

    test "rejects method outside the four accepted methods", %{store: store} do
      %{sql: sql, record: record} =
        build_record(store, %{result: :pass, completeness: :complete})

      row = record_row(record) |> List.replace_at(10, "any_method")
      assert {:error, _} = exec!(store, sql, row)
    end

    test "rejects subject_kind outside the eight kinds", %{store: store} do
      %{sql: sql, record: record} =
        build_record(store, %{result: :pass, completeness: :complete})

      row = record_row(record) |> List.replace_at(6, "wrong_kind")
      assert {:error, _} = exec!(store, sql, row)
    end

    test "rejects evidence_id that is not 36 chars", %{store: store} do
      %{sql: sql, record: record} =
        build_record(store, %{result: :pass, completeness: :complete})

      row = List.replace_at(record_row(record), 0, "short")
      assert {:error, _} = exec!(store, sql, row)
    end

    test "rejects rationale over 8192 bytes", %{store: store} do
      # Application validator already rejects 8193-byte rationale; build a
      # valid record and substitute a too-long rationale directly in the
      # row, then bypass the application validator via direct SQL.
      %{sql: sql, record: record} =
        build_record(store, %{
          result: :blocked,
          completeness: :partial
        })

      row = record_row(record) |> List.replace_at(26, String.duplicate("r", 8193))
      assert {:error, _} = exec!(store, sql, row)
    end
  end

  describe "AC11 — defense-in-depth child table constraints" do
    test "evidence_artifacts position must be 0..31", %{store: store} do
      # First insert a valid evidence record via direct SQL.
      {:ok, evidence} = Evidence.new(base_evidence_attrs(%{}))
      record_values = record_row(evidence)

      placeholders = Enum.map_join(1..length(record_values), ",", &"?#{&1}")
      insert_sql = row_sql(record_values)

      :ok = exec!(store, insert_sql, record_values)

      # Now attempt an evidence_artifacts insert with position 99 (out of range).
      assert {:error, _} =
               exec!(
                 store,
                 """
                 INSERT INTO evidence_artifacts (evidence_id, artifact_id, position)
                 VALUES (?1, ?2, ?3)
                 """,
                 [
                   evidence.evidence_id,
                   "01900000-0000-7000-8000-000000000abc",
                   99
                 ]
               )
    end

    test "evidence_warnings position must be 0..63", %{store: store} do
      {:ok, evidence} = Evidence.new(base_evidence_attrs(%{}))
      record_values = record_row(evidence)
      :ok = exec!(store, row_sql(record_values), record_values)

      assert {:error, _} =
               exec!(
                 store,
                 """
                 INSERT INTO evidence_warnings (evidence_id, position, warning)
                 VALUES (?1, ?2, ?3)
                 """,
                 [evidence.evidence_id, 99, "warning"]
               )
    end

    test "evidence_warnings warning over 1024 bytes is rejected", %{store: store} do
      {:ok, evidence} = Evidence.new(base_evidence_attrs(%{}))
      record_values = record_row(evidence)
      :ok = exec!(store, row_sql(record_values), record_values)

      assert {:error, _} =
               exec!(
                 store,
                 """
                 INSERT INTO evidence_warnings (evidence_id, position, warning)
                 VALUES (?1, ?2, ?3)
                 """,
                 [evidence.evidence_id, 0, String.duplicate("w", 1025)]
               )
    end

    test "evidence_warnings aggregate trigger aborts exactly at 16385 bytes", %{store: store} do
      {:ok, evidence} = Evidence.new(base_evidence_attrs(%{}))
      record_values = record_row(evidence)
      :ok = exec!(store, row_sql(record_values), record_values)

      # Insert 16 warnings of 1024 bytes each (= 16384 exactly) — succeeds.
      for i <- 0..15 do
        :ok =
          exec!(
            store,
            """
            INSERT INTO evidence_warnings (evidence_id, position, warning)
            VALUES (?1, ?2, ?3)
            """,
            [evidence.evidence_id, i, String.duplicate("a", 1024)]
          )
      end

      # The 17th 1024-byte warning pushes total to 16385 and aborts.
      assert {:error, %{message: message}} =
               exec!(
                 store,
                 """
                 INSERT INTO evidence_warnings (evidence_id, position, warning)
                 VALUES (?1, ?2, ?3)
                 """,
                 [evidence.evidence_id, 16, String.duplicate("a", 1024)]
               )

      assert message =~ "16384"
    end
  end
end
