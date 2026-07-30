defmodule Kiln.CLITest do
  @moduledoc """
  Protected fixtures for the foundation CLI dispatcher.

  Every test starts from a blank per-case temporary `$KILN_HOME` so the
  end-to-end command, journal, projection, and restart behavior all run
  through the same boundary the packaged CLI will exercise. Text and JSON
  outputs describe equivalent authoritative state; the dispatcher never
  reaches into the Repository, provider, Context, Patch, Command, Evidence,
  Receipt, Child, or TUI behaviour (P1-S01-T04-R12, R13).
  """

  use ExUnit.Case, async: true

  alias Kiln.CLI
  alias Kiln.CLI.{JsonRenderer, Request, Result, TextRenderer}
  alias Kiln.Domain.{Action, Id}
  alias Kiln.Store
  alias Kiln.Store.{Connection, Journal}
  alias Kiln.Test.JournalBuilder, as: JB

  @at ~U[2026-07-29 13:30:00Z]
  @now "2026-07-29T13:30:00Z"
  @test_root "/tmp/kiln-cli-fixture"

  setup do
    dir = tmp_home!()
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, dir: dir}
  end

  test "starting one Session creates durable Session, Task, and Run", %{dir: dir} do
    request =
      parse_request(dir, :start, [
        "--repo",
        @test_root,
        "--objective",
        "Fix one defect",
        "--criterion",
        "Test passes",
        "--constraint",
        "No new deps",
        "--exclude",
        "No provider"
      ])

    assert {%Result{status: :ok, exit_code: 0} = result, 0} = CLI.run(request)

    assert result.command == "start"
    assert is_integer(result.session_revision)
    assert result.journal_digest =~ ~r/^sha256:[0-9a-f]{64}$/
    assert result.data.objective == "Fix one defect"
    assert result.data.session_id =~ ~r/^ses_[0-9a-f]{32}$/

    {:ready, store} =
      Store.start(path: Path.join(dir, "state.sqlite3"), store_id: "store_cli_test", now: @now)

    on_exit(fn -> stop(store.conn) end)

    [[count]] = Connection.query!(store.conn, "SELECT count(*) FROM journal_entries")
    assert count == 1

    [[projection_count]] =
      Connection.query!(store.conn, "SELECT count(*) FROM session_projections")

    assert projection_count == 1
  end

  test "text and structured start results describe the same state", %{dir: dir} do
    text_request =
      parse_request(dir, :start, [
        "--repo",
        @test_root,
        "--objective",
        "Defect",
        "--criterion",
        "Passes"
      ])

    {text_result, 0} = CLI.run(text_request)
    text_rendered = TextRenderer.render(text_result)

    json_rendered = JsonRenderer.render(text_result)

    assert text_rendered =~ "session: ses_"
    assert text_rendered =~ "objective: Defect"

    decoded = JSON.decode!(json_rendered)
    assert decoded["kind"] == "cli_result"
    assert decoded["schema"] == "kiln.cli.result/v1"
    assert decoded["status"] == "ok"
    assert decoded["exit_code"] == 0
    assert decoded["data"]["objective"] == "Defect"
    assert decoded["data"]["session_id"] =~ ~r/^ses_[0-9a-f]{32}$/
    assert decoded["data"]["root_run_id"] =~ ~r/^run_[0-9a-f]{32}$/
    assert decoded["data"]["task_id"] =~ ~r/^tsk_[0-9a-f]{32}$/
  end

  test "status after restart matches the committed projection", %{dir: dir} do
    seed_request =
      parse_request(dir, :start, [
        "--repo",
        @test_root,
        "--objective",
        "Defect",
        "--criterion",
        "Passes"
      ])

    {_, 0} = CLI.run(seed_request)

    status_request = parse_request(dir, :status)
    {status_result, 0} = CLI.run(status_request)

    assert status_result.status == :ok
    assert status_result.exit_code == 0
    assert status_result.data.session_state == "active"
    assert status_result.data.run_state == "ready"
    assert status_result.data.workflow_step == "intent"
    assert status_result.data.orphaned == false
    assert is_binary(status_result.data.journal_head)

    decoded = decode_payload(status_result)
    assert decoded["data"]["run_state"] == "ready"
  end

  test "inspect exposes the complete accepted P1-S01 state", %{dir: dir} do
    seed_request =
      parse_request(dir, :start, [
        "--repo",
        @test_root,
        "--objective",
        "Defect",
        "--criterion",
        "Passes",
        "--constraint",
        "No deps",
        "--exclude",
        "No provider"
      ])

    {_, 0} = CLI.run(seed_request)

    inspect_request = parse_request(dir, :inspect)
    {inspect_result, 0} = CLI.run(inspect_request)

    data = inspect_result.data
    assert data.session_state == "active"
    assert data.task_state == "in_progress"
    assert data.run_state == "ready"
    assert data.workflow_step == "intent"
    assert data.objective == "Defect"
    assert data.criteria == ["Passes"]
    assert data.constraints == ["No deps"]
    assert data.exclusions == ["No provider"]
    assert data.objective_revision == 0
    assert data.criteria_revision == 0
    assert is_binary(data.project_observation_id)
    assert is_binary(data.journal_head_digest)
    assert is_binary(data.projection_digest)
  end

  test "invalid lifecycle transition produces a stable error and no durable mutation",
       %{dir: dir} do
    seed_request =
      parse_request(dir, :start, [
        "--repo",
        @test_root,
        "--objective",
        "Defect",
        "--criterion",
        "Passes"
      ])

    {seed_result, 0} = CLI.run(seed_request)
    initial_digest = seed_result.journal_digest

    {:ready, store} =
      Store.start(path: Path.join(dir, "state.sqlite3"), store_id: "store_cli_test", now: @now)

    on_exit(fn -> stop(store.conn) end)

    [[before_entries]] = Connection.query!(store.conn, "SELECT count(*) FROM journal_entries")
    [[before_commits]] = Connection.query!(store.conn, "SELECT count(*) FROM action_commits")

    # Cancel succeeds from `ready`, writing one journal row. A second cancel
    # must be a classified `failed` (terminal state) without writing again.
    first_cancel = parse_request(dir, :cancel, "--reason", "first")
    {first_cancel_result, 0} = CLI.run(first_cancel)
    assert first_cancel_result.status == :ok

    second_cancel = parse_request(dir, :cancel, "--reason", "second")
    {second_cancel_result, code} = CLI.run(second_cancel)
    assert code == 6
    assert second_cancel_result.status == :failed
    assert hd(second_cancel_result.errors).message =~ "already canceled"

    [[after_entries]] = Connection.query!(store.conn, "SELECT count(*) FROM journal_entries")
    [[after_commits]] = Connection.query!(store.conn, "SELECT count(*) FROM action_commits")

    assert after_entries - before_entries == 1
    assert after_commits - before_commits == 1

    _ = initial_digest
  end

  test "cancel succeeds from :ready and rebuilds to :canceled", %{dir: dir} do
    seed =
      parse_request(dir, :start, ["--repo", @test_root, "--objective", "D", "--criterion", "P"])

    {_, 0} = CLI.run(seed)

    request = parse_request(dir, :cancel, "--reason", "stop early")
    {result, 0} = CLI.run(request)

    assert result.status == :ok
    assert result.data.previous_run_state == "ready"
    assert result.data.run_state == "canceled"

    status_request = parse_request(dir, :status)
    {status_result, 0} = CLI.run(status_request)

    assert status_result.data.session_state == "abandoned"
    assert status_result.data.task_state == "abandoned"
    assert status_result.data.run_state == "canceled"
  end

  test "cancel is blocked when an active external operation is recorded",
       %{dir: dir} do
    seed_request =
      parse_request(dir, :start, [
        "--repo",
        @test_root,
        "--objective",
        "Defect",
        "--criterion",
        "Passes"
      ])

    {start_result, 0} = CLI.run(seed_request)
    session_id = start_result.data.session_id
    run_id = start_result.data.root_run_id

    {:ready, store} =
      Store.start(path: Path.join(dir, "state.sqlite3"), store_id: "store_cli_test", now: @now)

    on_exit(fn -> stop(store.conn) end)

    commit_intent(store, session_id, run_id, operation_id(:active), 0)

    request = parse_request(dir, :cancel, "--reason", "stop early")
    {result, code} = CLI.run(request)

    assert code == 4
    assert result.status == :blocked
    assert hd(result.errors).message =~ "active or unknown operation"
  end

  test "resume reports the current projection and next actions without performing work",
       %{dir: dir} do
    request =
      parse_request(dir, :start, [
        "--repo",
        @test_root,
        "--objective",
        "Defect",
        "--criterion",
        "Passes"
      ])

    {_, 0} = CLI.run(request)

    resume_request = parse_request(dir, :resume)
    {resume_result, 0} = CLI.run(resume_request)

    assert resume_result.status == :ok
    assert resume_result.data.run_state == "ready"
    actions = resume_result.data.next_actions
    assert Enum.any?(actions, &(&1.action == "inspect"))
    assert Enum.any?(actions, &(&1.action == "cancel"))

    {:ready, store} =
      Store.start(path: Path.join(dir, "state.sqlite3"), store_id: "store_cli_test", now: @now)

    on_exit(fn -> stop(store.conn) end)

    [[journal_rows]] = Connection.query!(store.conn, "SELECT count(*) FROM journal_entries")
    assert journal_rows == 1
  end

  test "pending decision appears accurately in status and inspect",
       %{dir: dir} do
    seed_request =
      parse_request(dir, :start, [
        "--repo",
        @test_root,
        "--objective",
        "Defect",
        "--criterion",
        "Passes"
      ])

    {start_result, 0} = CLI.run(seed_request)
    session_id = start_result.data.session_id
    run_id = start_result.data.root_run_id

    {:ready, store} =
      Store.start(path: Path.join(dir, "state.sqlite3"), store_id: "store_cli_test", now: @now)

    on_exit(fn -> stop(store.conn) end)

    commit_transition(store, session_id, run_id, "ready", "running", 0)

    commit_pending_decision(store, session_id, run_id, decision_id(:approval), 1)

    status_request = parse_request(dir, :status)
    {status_result, 0} = CLI.run(status_request)
    assert status_result.data.run_state == "waiting_for_user"
    assert status_result.data.pending_decision["id"] == decision_id(:approval)

    decoded = decode_payload(status_result)
    assert decoded["data"]["run_state"] == "waiting_for_user"
    assert decoded["data"]["pending_decision"]["id"] == decision_id(:approval)

    inspect_request = parse_request(dir, :inspect)
    {inspect_result, 0} = CLI.run(inspect_request)
    assert inspect_result.data.run_state == "waiting_for_user"
    assert inspect_result.data.pending_decision["permitted_responses"] == ["approve", "deny"]
  end

  test "unknown external operation reconstructs as orphaned Run and stays visible",
       %{dir: dir} do
    seed_request =
      parse_request(dir, :start, [
        "--repo",
        @test_root,
        "--objective",
        "Defect",
        "--criterion",
        "Passes"
      ])

    {start_result, 0} = CLI.run(seed_request)
    session_id = start_result.data.session_id
    run_id = start_result.data.root_run_id

    {:ready, store} =
      Store.start(path: Path.join(dir, "state.sqlite3"), store_id: "store_cli_test", now: @now)

    on_exit(fn -> stop(store.conn) end)

    commit_intent(store, session_id, run_id, operation_id(:active), 0)

    stop(store.conn)

    status_request = parse_request(dir, :status)
    {status_result, 7} = CLI.run(status_request)

    assert status_result.status == :unknown
    assert status_result.data.run_state == "orphaned"
    assert status_result.data.orphaned == true
    assert status_result.data.operation["state"] == "unknown"

    decoded = decode_payload(status_result)
    assert decoded["data"]["run_state"] == "orphaned"
    assert decoded["data"]["orphaned"] == true
    assert decoded["data"]["operation"]["state"] == "unknown"

    inspect_request = parse_request(dir, :inspect)
    {inspect_result, 7} = CLI.run(inspect_request)
    assert inspect_result.status == :unknown
    assert inspect_result.data.unknowns != []
    unknown = hd(inspect_result.data.unknowns)
    assert unknown["operation_id"] == operation_id(:active)
  end

  test "blocks explicitly when more than one Session exists", %{dir: dir} do
    seed1 =
      parse_request(dir, :start, [
        "--repo",
        @test_root,
        "--objective",
        "First",
        "--criterion",
        "Passes"
      ])

    {_, 0} = CLI.run(seed1)

    {:ready, store} =
      Store.start(path: Path.join(dir, "state.sqlite3"), store_id: "store_cli_test", now: @now)

    on_exit(fn -> stop(store.conn) end)

    # Insert a second session_started action with a different valid domain.

    d2 = JB.domain(9)
    action = JB.action(d2, :start_session, :local_user, "user:local", 0, 8, [])

    entry = JB.start_entry(d2)

    _ = Journal.commit(store.conn, action, [entry], now: @now)
    stop(store.conn)

    status_request = parse_request(dir, :status)
    {result, code} = CLI.run(status_request)

    assert code == 4
    assert result.status == :blocked
    assert hd(result.errors).code =~ "MULTIPLE_SESSIONS"
  end

  test "blocks explicitly on a corrupt journal", %{dir: dir} do
    seed_request =
      parse_request(dir, :start, [
        "--repo",
        @test_root,
        "--objective",
        "Defect",
        "--criterion",
        "Passes"
      ])

    {_, 0} = CLI.run(seed_request)

    {:ready, store} =
      Store.start(path: Path.join(dir, "state.sqlite3"), store_id: "store_cli_test", now: @now)

    on_exit(fn -> stop(store.conn) end)

    Connection.query!(
      store.conn,
      ~s|UPDATE journal_entries SET payload = '{"tampered":true}' WHERE session_revision = 0|
    )

    stop(store.conn)

    status_request = parse_request(dir, :status)
    {result, code} = CLI.run(status_request)
    assert code == 7
    assert result.status == :unknown
  end

  test "structured output is deterministic and versioned", %{dir: dir} do
    seed_request =
      parse_request(dir, :start, [
        "--repo",
        @test_root,
        "--objective",
        "Defect",
        "--criterion",
        "Passes"
      ])

    {_, 0} = CLI.run(seed_request)

    status_request = parse_request(dir, :status)

    {a, 0} = CLI.run(status_request)
    {b, 0} = CLI.run(status_request)

    rendered_a = JsonRenderer.render(a)
    rendered_a_again = JsonRenderer.render(a)
    rendered_b = JsonRenderer.render(b)

    assert rendered_a == rendered_a_again

    payload = JSON.decode!(rendered_a)
    payload_b = JSON.decode!(rendered_b)
    assert Map.delete(payload, "emitted_at") == Map.delete(payload_b, "emitted_at")
    assert payload["schema"] == "kiln.cli.result/v1"
    assert payload["kind"] == "cli_result"
    assert payload["exit_code"] in [0, 2, 3, 4, 5, 6, 7, 8, 9, 10]

    assert payload["status"] in [
             "ok",
             "denied",
             "blocked",
             "stale",
             "failed",
             "unknown",
             "unsupported"
           ]
  end

  test "excluded provider, Repository-read, Patch, Command, Evidence, Receipt, Child, and TUI commands are unreachable" do
    forbidden = [
      "investigate",
      "context.build",
      "context.inspect",
      "patch.list",
      "patch.inspect",
      "patch.approve",
      "patch.deny",
      "patch.apply",
      "verify.run",
      "command.status",
      "command.cancel",
      "evidence.list",
      "evidence.show",
      "criteria.show",
      "completion.inspect",
      "completion.accept",
      "completion.reject",
      "receipt.show",
      "receipt.verify",
      "receipt.rebuild",
      "recover.inspect",
      "recover.resolve",
      "run.show",
      "history",
      "session.show",
      "run.cancel",
      "doctor",
      "project.init",
      "provider.status"
    ]

    for command <- forbidden do
      argv = ["--kiln-home", "/tmp/excluded", command]

      assert {:error, error} = Request.parse(argv),
             "expected #{command} to be rejected at parse time"

      assert error.code == "USAGE_ERROR",
             "expected #{command} to reject with USAGE_ERROR, got #{inspect(error)}"

      assert error.message =~ "unsupported command",
             "expected #{command} to reject with unsupported command, got #{inspect(error)}"
    end
  end

  test "unsupported commands emit `unsupported` status with exit 9 when dispatched",
       %{dir: dir} do
    valid_request =
      parse_request(dir, :start, [
        "--repo",
        @test_root,
        "--objective",
        "Defect",
        "--criterion",
        "P"
      ])

    unsupported_request = %{valid_request | command: :patch_inspect}

    assert {%Result{status: :unsupported, exit_code: 9} = result, 9} =
             CLI.run(unsupported_request)

    assert result.command == "patch_inspect"
    assert hd(result.errors).code == "UNSUPPORTED_COMMAND"
    refute File.exists?(Path.join(dir, "state.sqlite3"))
  end

  test "unknown status reflects unknown external effect conservatively", %{dir: dir} do
    seed_request =
      parse_request(dir, :start, [
        "--repo",
        @test_root,
        "--objective",
        "Defect",
        "--criterion",
        "Passes"
      ])

    {start_result, 0} = CLI.run(seed_request)
    session_id = start_result.data.session_id
    run_id = start_result.data.root_run_id

    {:ready, store} =
      Store.start(path: Path.join(dir, "state.sqlite3"), store_id: "store_cli_test", now: @now)

    on_exit(fn -> stop(store.conn) end)

    commit_intent(store, session_id, run_id, operation_id(:active), 0)

    stop(store.conn)

    resume_request = parse_request(dir, :resume)
    {resume_result, 7} = CLI.run(resume_request)

    assert resume_result.status == :unknown
    assert resume_result.data.run_state == "orphaned"
    assert resume_result.data.session_state == "active"
    actions = resume_result.data.next_actions
    assert Enum.any?(actions, &(&1.action == "inspect"))
  end

  # -- helpers --

  defp operation_id(:active), do: opaque_id(:operation, 0xA1)
  defp decision_id(:approval), do: opaque_id(:decision, 0xD1)

  defp opaque_id(kind, byte) do
    {:ok, id} = Id.generate(kind, fn 16 -> :binary.copy(<<byte>>, 16) end)
    id
  end

  defp parse_request(dir, command) do
    {:ok, request} = Request.parse(["--kiln-home", dir, Atom.to_string(command)])
    request
  end

  defp parse_request(dir, command, opts) do
    argv = ["--kiln-home", dir, Atom.to_string(command) | opts]
    {:ok, request} = Request.parse(argv)
    request
  end

  defp parse_request(dir, command, opt1, opt2) do
    argv = ["--kiln-home", dir, Atom.to_string(command), opt1, opt2]
    {:ok, request} = Request.parse(argv)
    request
  end

  defp decode_payload(result) do
    decoded = JSON.decode!(JsonRenderer.render(result))
    decoded
  end

  # Commit a deterministic run transition through the existing Journal boundary
  # so the CLI test exercises real durable state without bypassing domain.
  defp commit_transition(store, session_id, run_id, from, to, expected_revision) do
    idempotency_key = "idem_" <> String.duplicate("0", 32)
    request_digest = "sha256:" <> String.duplicate("a", 64)

    {:ok, action_id} =
      Id.generate(:action, fn 16 -> :binary.copy(<<expected_revision + 5>>, 16) end)

    {:ok, action} =
      Action.new(%{
        id: action_id,
        session_id: session_id,
        run_id: run_id,
        expected_session_revision: expected_revision,
        idempotency_key: idempotency_key,
        actor_kind: :system,
        actor_id: "kiln:workflow",
        kind: :transition_run,
        request_digest: request_digest,
        payload: %{from: from, to: to},
        causation_action_id: nil,
        correlation_id: nil,
        requested_at: @at
      })

    entry = %{
      type: "run_transitioned/v1",
      payload_schema: "run_transitioned/v1",
      payload: %{
        "run" => %{"from" => from, "to" => to},
        "workflow_step" => "application"
      }
    }

    {:ok, _} = Journal.commit(store.conn, action, [entry], now: @now)
  end

  defp commit_intent(store, session_id, run_id, operation_id, expected_revision) do
    idempotency_key = "idem_" <> String.duplicate("1", 32)
    request_digest = "sha256:" <> String.duplicate("c", 64)

    {:ok, action_id} =
      Id.generate(:action, fn 16 -> :binary.copy(<<expected_revision + 9>>, 16) end)

    {:ok, action} =
      Action.new(%{
        id: action_id,
        session_id: session_id,
        run_id: run_id,
        expected_session_revision: expected_revision,
        idempotency_key: idempotency_key,
        actor_kind: :system,
        actor_id: "kiln:workflow",
        kind: :record_operation_intent,
        request_digest: request_digest,
        payload: %{},
        causation_action_id: nil,
        correlation_id: nil,
        requested_at: @at
      })

    entry = %{
      type: "external_operation_intent_recorded/v1",
      payload_schema: "external_operation_intent_recorded/v1",
      payload: %{
        "operation" => %{"id" => operation_id, "class" => "command_execution"},
        "workflow_step" => "application"
      }
    }

    {:ok, _} = Journal.commit(store.conn, action, [entry], now: @now)
  end

  defp commit_pending_decision(store, session_id, run_id, decision_id, expected_revision) do
    idempotency_key = "idem_" <> String.duplicate("2", 32)
    request_digest = "sha256:" <> String.duplicate("d", 64)

    {:ok, action_id} =
      Id.generate(:action, fn 16 -> :binary.copy(<<expected_revision + 11>>, 16) end)

    {:ok, action} =
      Action.new(%{
        id: action_id,
        session_id: session_id,
        run_id: run_id,
        expected_session_revision: expected_revision,
        idempotency_key: idempotency_key,
        actor_kind: :system,
        actor_id: "kiln:workflow",
        kind: :request_decision,
        request_digest: request_digest,
        payload: %{},
        causation_action_id: nil,
        correlation_id: nil,
        requested_at: @at
      })

    decision = %{
      "id" => decision_id,
      "subject_kind" => "run",
      "subject_id" => run_id,
      "subject_revision" => expected_revision,
      "requested_actor" => "local_user",
      "permitted_responses" => ["approve", "deny"]
    }

    entry = %{
      type: "pending_decision_recorded/v1",
      payload_schema: "pending_decision_recorded/v1",
      payload: %{"decision" => decision, "workflow_step" => "approval"}
    }

    {:ok, _} = Journal.commit(store.conn, action, [entry], now: @now)
  end

  defp tmp_home! do
    dir = Path.join(System.tmp_dir!(), "kiln-cli-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    dir
  end

  defp stop(conn) do
    if Process.alive?(conn), do: GenServer.stop(conn)
    :ok
  catch
    :exit, _reason -> :ok
  end
end
