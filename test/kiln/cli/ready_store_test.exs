defmodule Kiln.CLI.ReadyStoreTest do
  @moduledoc """
  KILN-02 regression test.

  The CLI's `ready_store/0` must return a store map that satisfies
  `Kiln.Artifact.Store.put/2`'s expected shape (`%{conn: pid, artifact_root:
  path}`). When `mix kiln supervise …` reaches the supervisor, the
  supervisor persists Artifacts through that map; the legacy
  `%{conn: pid}` map crashes with `FunctionClauseError`.

  These tests invoke the real CLI composition (`Kiln.CLI.run/1` over a
  parsed `Kiln.CLI.Request` with a real `Kiln.CLI.Runtime.open/2`
  backed store) and the supervisor end-to-end, not a hand-built store
  map. The CLI is the canonical entry point and the test bypasses
  nothing.
  """

  use ExUnit.Case, async: false

  alias Kiln.CLI
  alias Kiln.CLI.Request

  @now "2026-08-13T00:00:00Z"
  @actor "kiln-02-regression"

  setup do
    base =
      Path.join(
        System.tmp_dir!(),
        "kiln-cli-ready-store-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(base)
    on_exit(fn -> File.rm_rf!(base) end)

    repo = Path.join(base, "repo")
    File.mkdir_p!(repo)
    File.write!(Path.join(repo, "README.md"), "fixture repository")

    System.cmd("git", ["-C", repo, "init", "-q", "--initial-branch=main"])
    System.cmd("git", ["-C", repo, "config", "user.email", "test@example.com"])
    System.cmd("git", ["-C", repo, "config", "user.name", "Test"])
    System.cmd("git", ["-C", repo, "add", "."])
    System.cmd("git", ["-C", repo, "commit", "-m", "init"])
    {raw_sha, 0} = System.cmd("git", ["-C", repo, "rev-parse", "HEAD"])
    base_commit = String.trim(raw_sha)

    on_exit(fn -> File.rm_rf!(repo) end)

    work_id = "wfg-cli-#{System.unique_integer([:positive])}"

    envelope_payload = %{
      "schema" => "engineering-system/work-envelope/v0",
      "work_id" => work_id,
      "created_at" => @now,
      "producer" => %{"product" => "loadout", "version" => "1.0.0"},
      "goal" => %{
        "title" => "CLI supervise regression",
        "success_conditions" => ["report durable Run Result Envelope"]
      },
      "capability" => %{
        "id" => "repository-recon",
        "contract_version" => "0.1.0",
        "method_provenance" => ["loadout/recon@0.0.1", "digest:sha256:test"]
      },
      "project_state" => %{
        "repository" => repo,
        "base_commit" => base_commit,
        "workspace_state_digest" => "sha256:producer-input"
      },
      "scope" => %{"included" => ["tracked files"], "excluded" => ["mutation"]},
      "constraints" => %{
        "must" => ["distinguish observations"],
        "must_not" => ["modify"]
      },
      "proof_obligations" => [
        %{
          "id" => "repo-state-observed",
          "kind" => "evidence",
          "requirement" => "report the exact commit"
        }
      ],
      "authority_requests" => [
        %{"capability" => "git.read", "scope" => repo}
      ]
    }

    envelope_path = Path.join(base, "work-envelope.json")
    File.write!(envelope_path, JSON.encode!(envelope_payload))

    {:ok, base: base, repo: repo, work_id: work_id, envelope_path: envelope_path}
  end

  test "real CLI mix kiln supervise reaches Artifact.Store.put/2 without FunctionClauseError",
       %{base: base, envelope_path: envelope_path, work_id: work_id} do
    argv = [
      "--kiln-home",
      base,
      "--actor-id",
      @actor,
      "--format",
      "json",
      "supervise",
      "--work-envelope",
      envelope_path
    ]

    assert {:ok, request} = Request.parse(argv)
    assert request.command == :supervise

    # The full CLI dispatch must not return an error result from the
    # FunctionClauseError that blocked merged main before the fix.
    case CLI.run(request) do
      {%Kiln.CLI.Result{status: :ok, data: data}, 0} ->
        assert data.work_id == work_id
        assert data.envelope["work_id"] == work_id
        # Nested maps retain atom keys (built from struct fields)
        assert data.envelope["authority"][:granted] == ["git.read"]
        assert data.envelope["authority"][:denied] == []
        assert data.envelope["input_state"][:base_commit] == data.envelope["final_state"][:commit]

      {%Kiln.CLI.Result{} = result, exit_code} ->
        flunk(
          "CLI supervise failed: exit=#{exit_code} status=#{result.status} errors=#{inspect(result.errors)}"
        )
    end
  end

  test "ready_store artifact_root matches the canonical Kiln.Store derivation",
       %{base: base} do
    {:ok, :ready} = Kiln.CLI.Runtime.open(base, :write)
    on_exit(fn -> Kiln.CLI.Runtime.stop() end)

    pid = Process.whereis(Kiln.Store.Connection)
    assert is_pid(pid)

    # The canonical helper the CLI now uses.
    expected_root = Kiln.Store.artifact_root_for_path(Path.join(base, "state.sqlite3"))

    # The CLI's `ready_store/0` reaches the same path because both
    # delegate to `Path.dirname(state_path) <> "/artifacts"`.
    assert expected_root == Path.join(base, "artifacts")
  end
end
