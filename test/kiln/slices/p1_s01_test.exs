defmodule Kiln.Slices.P1S01Test do
  @moduledoc """
  P1-S01 aggregate slice assertions.

  This module is deliberately **not** a second copy of the T01-T04/T06 unit
  suites. Those prove each contract in isolation. This module proves the
  properties that only exist once the tickets are integrated:

    * the protected failure matrix still produces its exact classification
      when reached through the integrated boundary (`Kiln.CLI.Runtime` and
      `Kiln.Workflow`) rather than through a store-level unit fixture;
    * a fixture that is *expected* to fail is observed to fail with the
      exact expected classification, so an expected failure can never be
      mistaken for aggregate success, and an aggregate pass can never be
      produced by a harness that aborted before classifying;
    * subsystems deferred past P1-S01 are unreachable, not merely undocumented;
    * the real `mix kiln` entry point works as an operating-system process,
      which the in-process T04 dispatcher tests could not observe.
  """

  use ExUnit.Case, async: false

  alias Kiln.CLI.Runtime
  alias Kiln.Domain.Error
  alias Kiln.Store
  alias Kiln.Store.Connection
  alias Kiln.Workflow

  @actor "slice-gate-actor"
  @repo_root "/tmp/kiln-slice-fixture"

  setup do
    home = tmp_home!()
    on_exit(fn -> File.rm_rf!(home) end)
    {:ok, home: home, path: Path.join(home, "state.sqlite3")}
  end

  # ------------------------------------------------------------------
  # Protected failure matrix
  #
  # Each test names the CASE, the EXPECTED classification, and asserts the
  # OBSERVED classification matches exactly. `assert {:error, ...} = ...`
  # with a specific code is used rather than `refute match?({:ok, _}, ...)`
  # so a *different* failure cannot be scored as the expected protection.
  # ------------------------------------------------------------------

  describe "protected failure matrix (AC03)" do
    test "CASE corrupt journal — EXPECTED integrity block at open, not fake success", %{
      home: home,
      path: path
    } do
      start_one_session!(home)

      # Overwrite the SQLite header so the file is no longer a database.
      File.write!(path, "not-a-sqlite-database" <> String.duplicate("\0", 200))

      assert {:blocked, :integrity_blocked, _} = Runtime.open(home, :read)

      # The blocked classification must not delete or truncate the file.
      assert File.exists?(path)
    end

    test "CASE corrupt projection cache — EXPECTED journal rebuild wins, stale cache never served",
         %{home: home} do
      %{session_id: session_id, digest: authoritative_digest} = start_one_session!(home)

      # Plant a well-formed but false cached projection.
      with_store(home, fn conn ->
        Connection.query!(
          conn,
          "UPDATE session_projections SET projection = ?1",
          [~s({"session":{"id":"ses_deadbeef","state":"canceled"},"run":{"state":"canceled"}})]
        )
      end)

      {:ok, %{projection: projection, source: source, projection_digest: digest}} =
        in_runtime(home, fn -> Workflow.query_session(session_id) end)

      # The false cache must be discarded, not returned.
      assert source == :rebuilt
      assert get_in(projection, ["session", "id"]) == session_id
      assert get_in(projection, ["run", "state"]) == "ready"
      assert digest == authoritative_digest

      # The cache row itself must be replaced, not merely shadowed in memory.
      # A second read in a *separate* runtime must still see the authoritative
      # projection, not the planted false one, so the fix is durable.
      in_runtime(home, fn ->
        [[cached]] =
          Connection.query!(
            Process.whereis(Kiln.Store.Connection),
            "SELECT projection FROM session_projections"
          )

        refute cached =~ "ses_deadbeef",
               "the false cached projection was not rewritten after the rebuild"

        {:ok, reread} = Workflow.query_session(session_id)
        assert reread.source in [:cache, :rebuilt]
        assert get_in(reread.projection, ["session", "id"]) == session_id
      end)
    end

    test "CASE modified applied migration — EXPECTED migration block", %{home: home} do
      start_one_session!(home)

      # Rewrite the recorded checksum of an applied migration so the bundled
      # file no longer matches what the store recorded as applied.
      with_store(home, fn conn ->
        Connection.query!(
          conn,
          "UPDATE schema_migrations SET checksum = ?1 WHERE version = 1",
          [String.duplicate("a", 64)]
        )
      end)

      assert {:blocked, :migration_blocked, _} = Runtime.open(home, :read)
    end

    test "CASE future-version store — EXPECTED version block", %{home: home} do
      start_one_session!(home)

      with_store(home, fn conn ->
        Connection.query!(
          conn,
          "INSERT INTO schema_migrations (version, name, checksum, applied_at) VALUES (?1, ?2, ?3, ?4)",
          [9999, "from_a_newer_binary", String.duplicate("b", 64), "2026-01-01T00:00:00Z"]
        )
      end)

      assert {:blocked, :version_blocked, _} = Runtime.open(home, :read)
    end

    test "CASE stale expected revision — EXPECTED rejection with no durable write", %{home: home} do
      %{session_id: session_id} = start_one_session!(home)

      in_runtime(home, fn ->
        before = row_counts()

        assert {:error, %Error{} = error} =
                 Workflow.cancel_session(session_id,
                   actor_id: @actor,
                   expected_session_revision: 999
                 )

        assert error.code in [:stale_revision, :expected_revision_mismatch, :revision_conflict],
               "unexpected error code for a stale revision: #{inspect(error.code)}"

        assert row_counts() == before,
               "a rejected stale-revision action performed a durable write"
      end)
    end

    test "CASE conflicting idempotency key — EXPECTED idempotency_conflict with no durable write",
         %{home: home} do
      in_runtime(home, fn ->
        key = "idem_" <> String.duplicate("c", 32)

        assert {:ok, _} = Workflow.start_session(start_opts(idempotency_key: key))

        after_first = row_counts()

        # Same key, different request digest (different objective).
        assert {:error, %Error{code: :idempotency_conflict}} =
                 Workflow.start_session(
                   start_opts(idempotency_key: key, objective: "a different objective")
                 )

        assert row_counts() == after_first,
               "a conflicting idempotency key performed a durable write"
      end)
    end

    test "CASE nonterminal operation across restart — EXPECTED orphaned, never silent success", %{
      home: home
    } do
      %{session_id: session_id} = start_one_session!(home)

      # Plant a nonterminal external operation directly in the journal, then
      # reconstruct in a *fresh* runtime, as a restart would.
      with_store(home, fn conn -> plant_nonterminal_operation!(conn, session_id) end)

      {:ok, result} = in_runtime(home, fn -> Workflow.query_session(session_id) end)

      assert result.orphaned == true
      assert get_in(result.projection, ["operation", "state"]) != nil

      # An orphaned Run must advertise no executable mutation.
      {:ok, actions} = in_runtime(home, fn -> Workflow.valid_next_actions(session_id) end)
      assert actions == []
    end
  end

  # ------------------------------------------------------------------
  # Harness self-protection
  # ------------------------------------------------------------------

  describe "harness cannot score an expected failure as success (AC03)" do
    test "a blocked store never yields a readable Workflow result" do
      home = tmp_home!()
      on_exit(fn -> File.rm_rf!(home) end)
      File.write!(Path.join(home, "state.sqlite3"), "corrupt")

      assert {:blocked, :integrity_blocked, _} = Runtime.open(home, :read)

      # No connection may be left registered after a blocked open, so a later
      # query cannot accidentally read a half-open store and report success.
      assert Process.whereis(Kiln.Store.Connection) == nil
      assert {:error, %Error{code: :store_unavailable}} = Workflow.current_session()
    end
  end

  # ------------------------------------------------------------------
  # Excluded-capability audit (AC06)
  # ------------------------------------------------------------------

  describe "deferred subsystems are unreachable (AC06)" do
    test "no compiled module occupies a deferred subsystem namespace" do
      forbidden = [
        ~r/^Elixir\.Kiln\.Provider/,
        ~r/^Elixir\.Kiln\.FakeProvider/,
        ~r/^Elixir\.Kiln\.Context/,
        ~r/^Elixir\.Kiln\.Tool/,
        ~r/^Elixir\.Kiln\.Patch/,
        ~r/^Elixir\.Kiln\.Mutation/,
        ~r/^Elixir\.Kiln\.Receipt/,
        ~r/^Elixir\.Kiln\.Release/,
        ~r/^Elixir\.Kiln\.Child/,
        ~r/^Elixir\.Kiln\.TUI/,
        ~r/^Elixir\.Kiln\.MCP/,
        ~r/^Elixir\.Kiln\.WaveB/,
        ~r/^Elixir\.Kiln\.QualityCompiler/,
        ~r/^Elixir\.Kiln\.Pack/
      ]

      offenders =
        for module <- kiln_modules(),
            name = Atom.to_string(module),
            Enum.any?(forbidden, &Regex.match?(&1, name)),
            do: name

      assert offenders == [], "deferred subsystem modules are present: #{inspect(offenders)}"
    end

    test "the provider and command-host boundaries are behaviours with no implementation" do
      for behaviour <- [Kiln.Conformance.Provider, Kiln.Conformance.CommandHost] do
        # The behaviour declares callbacks but exports no callable API beyond
        # `behaviour_info/1`, so it cannot execute anything.
        callable =
          behaviour.__info__(:functions)
          |> Enum.reject(fn {name, _arity} -> name == :behaviour_info end)

        assert callable == [],
               "#{inspect(behaviour)} exports callable functions: #{inspect(callable)}"

        implementors =
          Enum.filter(kiln_modules(), fn module ->
            module != behaviour and
              behaviour in List.wrap(module.module_info(:attributes)[:behaviour])
          end)

        assert implementors == [],
               "#{inspect(behaviour)} has implementations: #{inspect(implementors)}"
      end
    end

    test "no P1-S01 runtime module can execute an external process or shell" do
      # The KIL-W3 supervisor explicitly authorizes `git.read` and uses
      # `git rev-parse HEAD` to resolve the current commit; that module
      # is excluded from the P1-S01 check because the Wave 3 wedge
      # authorizes the call.
      offenders =
        for path <- Path.wildcard("lib/**/*.ex"),
            path != "lib/kiln/repository_observation.ex",
            source = File.read!(path),
            Regex.match?(~r/System\.cmd|System\.shell|Port\.open|:os\.cmd|open_port/, source),
            do: path

      assert offenders == [],
             "external-process execution is reachable from P1-S01 runtime source: #{inspect(offenders)}"
    end

    test "the CLI exposes the authorized P1-S01 commands" do
      # KIL-W3 adds `:supervise` for the Wave 3 wedge; that command is
      # authorized by `docs/authorizations/KIL-W3.authorization` and is
      # the only command outside the P1-S01 surface.
      assert Enum.sort(Kiln.CLI.Request.commands()) ==
               Enum.sort([:start, :status, :inspect, :cancel, :resume, :supervise])
    end

    test "no P1-S01 runtime module reads Repository source content" do
      # P1-S01 records Repository *metadata* only (root path, fingerprint,
      # observed_at). No P1-S01 runtime module may read file contents
      # from the active Repository. The KIL-W3 supervisor reads the
      # repository manifest by explicit Wave 3 authorization; its
      # observation module is excluded here and verified separately.
      # Artifact.Store.read/2 reads only Kiln-owned Artifact content,
      # not source from the active Repository, and is covered by the
      # P3-W01 reconstruction tests.
      offenders =
        for path <- Path.wildcard("lib/**/*.ex"),
            path != "lib/kiln/store/migrations.ex",
            path != "lib/kiln/artifact/store.ex",
            path != "lib/kiln/repository_observation.ex",
            path != "lib/kiln/work_envelope_loader.ex",
            source = File.read!(path),
            Regex.match?(~r/File\.read!?\(|File\.stream!|File\.ls!?\(/, source),
            do: path

      assert offenders == [],
             "Repository source read is reachable from runtime source: #{inspect(offenders)}"
    end
  end

  # ------------------------------------------------------------------
  # Integrated entry-point regression (owning contract: P1-S01-T04-R01)
  # ------------------------------------------------------------------

  describe "the real mix kiln entry point runs as an operating-system process" do
    @tag :integration
    test "mix kiln start then inspect reconstructs identical state in a separate process" do
      home = tmp_home!()
      repo = tmp_home!()
      on_exit(fn -> File.rm_rf!(home) end)
      on_exit(fn -> File.rm_rf!(repo) end)

      {start_out, start_status} =
        mix_kiln([
          "--format",
          "json",
          "--kiln-home",
          home,
          "--actor-id",
          @actor,
          "start",
          "--repo",
          repo,
          "--objective",
          "prove the durable foundation",
          "--criterion",
          "state survives restart"
        ])

      assert start_status == 0,
             "`mix kiln start` failed as a real process (exit #{start_status}): #{start_out}"

      started = decode_cli_json!(start_out)
      assert started["status"] == "ok"
      assert started["schema"] == "kiln.cli.result/v1"

      {inspect_out, inspect_status} =
        mix_kiln([
          "--format",
          "json",
          "--kiln-home",
          home,
          "--actor-id",
          @actor,
          "inspect"
        ])

      assert inspect_status == 0,
             "`mix kiln inspect` failed as a real process (exit #{inspect_status}): #{inspect_out}"

      inspected = decode_cli_json!(inspect_out)

      # A separate operating-system process reproduces the same identity and
      # the same digest, so the state came from the durable journal rather
      # than from the first process's memory.
      assert inspected["data"]["session_id"] == started["data"]["session_id"]
      assert inspected["data"]["task_id"] == started["data"]["task_id"]
      assert inspected["data"]["root_run_id"] == started["data"]["root_run_id"]
      assert inspected["journal_digest"] == started["journal_digest"]
    end
  end

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  defp mix_kiln(args) do
    System.cmd("mix", ["kiln" | args],
      cd: File.cwd!(),
      stderr_to_stdout: true,
      env: [{"MIX_ENV", "dev"}]
    )
  end

  defp decode_cli_json!(output) do
    output
    |> String.split("\n", trim: true)
    |> Enum.reverse()
    |> Enum.find_value(fn line ->
      case JSON.decode(line) do
        {:ok, %{"kind" => "cli_result"} = decoded} -> decoded
        _ -> nil
      end
    end)
    |> case do
      nil -> flunk("no kiln.cli.result/v1 document in CLI output:\n#{output}")
      decoded -> decoded
    end
  end

  defp start_opts(overrides) do
    Enum.into(overrides, %{
      actor_id: @actor,
      objective: "prove the durable foundation",
      criteria: ["state survives restart"],
      project_observation: %{
        repository_root: @repo_root,
        repository_fingerprint: "sha256:" <> String.duplicate("d", 64),
        observed_at: DateTime.utc_now()
      }
    })
  end

  defp start_one_session!(home) do
    in_runtime(home, fn ->
      {:ok, started} = Workflow.start_session(start_opts([]))
      %{session_id: started.session_id, digest: started.projection_digest}
    end)
  end

  # Run `fun` with the integrated CLI runtime open, exactly as a real command
  # does, and always close it so the next call re-opens from disk rather than
  # inheriting a live connection.
  defp in_runtime(home, fun) do
    {:ok, :ready} = Runtime.open(home, :write)

    try do
      fun.()
    after
      Runtime.stop()
    end
  end

  defp with_store(home, fun) do
    {:ready, store} =
      Store.start(path: Path.join(home, "state.sqlite3"), store_id: "slice_gate_fixture")

    try do
      fun.(store.conn)
    after
      GenServer.stop(store.conn, :normal, 5_000)
    end
  end

  defp row_counts do
    conn = Process.whereis(Kiln.Store.Connection)

    Map.new(["journal_entries", "action_commits", "session_projections"], fn table ->
      [[count]] = Connection.query!(conn, "SELECT count(*) FROM #{table}")
      {table, count}
    end)
  end

  # Plant an `external_operation_intent_recorded/v1` entry so the Run owns a
  # nonterminal operation with no terminal observation, which the conservative
  # restart classifier must reconstruct as orphaned.
  defp plant_nonterminal_operation!(conn, session_id) do
    d = Kiln.Test.JournalBuilder.domain(1)
    d = %{d | session: %{d.session | id: session_id}}
    store = %{conn: conn}
    Kiln.Test.JournalBuilder.commit_operation_intent(store, d, 0, 40)
  end

  defp kiln_modules do
    {:ok, modules} = :application.get_key(:kiln, :modules)
    modules
  end

  defp tmp_home! do
    dir =
      Path.join(
        System.tmp_dir!(),
        "kiln-slice-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    dir
  end
end
