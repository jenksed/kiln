defmodule Kiln.CLI.ResultTest do
  use ExUnit.Case, async: true

  alias Kiln.CLI.Result

  test "ok/2 builds a successful envelope with the agreed exit code" do
    result = Result.ok("start", data: %{session_id: "ses_1"}, session_revision: 0)
    assert result.status == :ok
    assert result.exit_code == 0
    assert result.command == "start"
    assert result.errors == []
    assert result.warnings == []
    assert result.session_revision == 0
    assert result.data == %{session_id: "ses_1"}
    assert is_binary(result.emitted_at)
  end

  test "error/3 builds a typed envelope with the agreed exit code" do
    result =
      Result.error("cancel", :failed,
        errors: [
          Result.to_error(%{
            code: :terminal_run_state,
            message: "Run is already completed"
          })
        ]
      )

    assert result.status == :failed
    assert result.exit_code == 6
    assert result.command == "cancel"
    assert length(result.errors) == 1
    assert hd(result.errors).code == "TERMINAL_RUN_STATE"
    assert hd(result.errors).message == "Run is already completed"
  end

  test "exit_for/1 maps every accepted status to the schema exit codes" do
    assert Result.exit_for(:ok) == 0
    assert Result.exit_for(:denied) == 3
    assert Result.exit_for(:blocked) == 4
    assert Result.exit_for(:stale) == 5
    assert Result.exit_for(:failed) == 6
    assert Result.exit_for(:unknown) == 7
    assert Result.exit_for(:unsupported) == 9
  end

  test "an accepted status can use a distinct contract exit for usage or store failure" do
    usage = Result.error("start", :denied, exit_code: 2, errors: [Result.to_error("bad input")])

    store =
      Result.error("status", :blocked,
        exit_code: 8,
        errors: [Result.to_error("store unavailable")]
      )

    assert usage.exit_code == 2
    assert store.exit_code == 8
  end

  test "to_error/1 normalizes domain errors, atoms, and strings" do
    domain = Result.to_error(%{code: :stale_revision, message: "stale", details: %{a: 1}})
    assert domain.code == "STALE_REVISION"
    assert domain.class == "stale_revision"
    assert domain.details == %{"a" => 1}

    only_code = Result.to_error(:idempotency_conflict)
    assert only_code.code == "IDEMPOTENCY_CONFLICT"

    usage = Result.to_error("missing required argument")
    assert usage.code == "USAGE_ERROR"
    assert usage.class == "usage"
  end
end
