defmodule Kiln.Verification.SupervisionTest do
  use ExUnit.Case, async: false

  alias Kiln.Store
  alias Kiln.Verification.{Change, State, Supervision}

  @now "2026-08-13T22:00:00Z"

  setup do
    base =
      Path.join(
        System.tmp_dir!(),
        "kiln-verification-supervision-#{System.unique_integer([:positive])}"
      )

    repository = Path.join(base, "loadout")
    File.mkdir_p!(repository)
    File.write!(Path.join(repository, "README.md"), "baseline\n")
    git!(repository, ["init", "-q", "-b", "main"])
    git!(repository, ["config", "user.email", "test@local"])
    git!(repository, ["config", "user.name", "Test"])
    git!(repository, ["add", "."])
    git!(repository, ["commit", "-q", "-m", "baseline"])
    base_commit = git!(repository, ["rev-parse", "HEAD"]) |> String.trim()
    File.write!(Path.join(repository, "README.md"), "changed\n")
    {:ok, state} = State.observe(repository, base_commit)

    {:ready, store} =
      Store.start(
        path: Path.join(base, "state.sqlite3"),
        store_id: "verification_#{System.unique_integer([:positive])}",
        now: @now
      )

    on_exit(fn ->
      try do
        if Process.alive?(store.conn), do: GenServer.stop(store.conn)
      catch
        :exit, _ -> :ok
      end

      File.rm_rf!(base)
    end)

    {:ok,
     base: base, repository: repository, base_commit: base_commit, state: state, store: store}
  end

  test "passing registered command yields READY and reconstructs after restart", context do
    {envelope, change} = request(context, "wave6-pass")

    assert {:ok, result} =
             Supervision.supervise(envelope, change,
               store: context.store,
               actor_id: "test",
               now: @now,
               command_host: host(:pass)
             )

    assert result.status == :completed

    assert result.acceptance_readiness == %{
             ready: true,
             reasons: ["all declared proof obligations have durable satisfying Evidence"]
           }

    assert result.proof_obligations.satisfied == ["patch-hygiene"]
    assert result.proof_obligations.unsatisfied == []
    assert result.proof_obligations.invalidated == []
    assert Enum.any?(result.evidence, &String.contains?(&1["description"], "patch-hygiene: pass"))

    GenServer.stop(context.store.conn)

    {:ready, reopened} =
      Store.start(
        path: Path.join(context.base, "state.sqlite3"),
        store_id: "verification_reopened_#{System.unique_integer([:positive])}",
        now: @now
      )

    assert {:ok, reconstructed} = Kiln.Supervision.inspect_run(reopened, result.run_id)
    assert reconstructed == result
    GenServer.stop(reopened.conn)
  end

  test "failed command completes the Run but invalidates proof and never returns READY",
       context do
    {envelope, change} = request(context, "wave6-fail")

    assert {:ok, result} =
             Supervision.supervise(envelope, change,
               store: context.store,
               actor_id: "test",
               now: @now,
               command_host: host(:fail)
             )

    assert result.status == :completed
    assert result.acceptance_readiness.ready == false
    assert result.proof_obligations.satisfied == []
    assert result.proof_obligations.invalidated == ["patch-hygiene"]
    assert result.acceptance_readiness.reasons == ["failed proof obligations: patch-hygiene"]
  end

  test "denied command authority blocks without executing", context do
    {envelope, change} = request(context, "wave6-denied")
    parent = self()

    assert {:ok, result} =
             Supervision.supervise(envelope, change,
               store: context.store,
               actor_id: "test",
               now: @now,
               deny_capabilities: ["verification.run:repo.diff-check"],
               command_host: fn _command, _opts ->
                 send(parent, :executed)
                 host(:pass)
               end
             )

    assert result.status == :blocked
    assert result.acceptance_readiness.ready == false
    refute_received :executed
  end

  defp request(context, work_id) do
    obligation = %{
      "id" => "patch-hygiene",
      "kind" => "verification",
      "requirement" => "patch is clean",
      "required_commands" => ["repo.diff-check"]
    }

    command = %{
      "command_id" => "repo.diff-check",
      "executable" => "git",
      "argv" => ["diff", "--check", context.base_commit, "--"],
      "working_directory" => ".",
      "timeout_ms" => 30_000,
      "environment_policy" => "minimal-toolchain-path",
      "network_policy" => "not-required",
      "mutation_expectation" => "none",
      "proves" => ["patch-hygiene"],
      "rationale" => "every patch needs hygiene proof"
    }

    change = %{
      "schema" => "loadout/verification-change/v0",
      "method" => %{
        "id" => "verify-change/proof-obligation",
        "version" => "1.0.0",
        "implementation_digest" =>
          "sha256:13a137f778a479f01d1b90ab9640dceed893a824a06fc386f4df925164a4c0e9",
        "selection_result_digest" => "sha256:" <> String.duplicate("b", 64),
        "arsenal_commit" => String.duplicate("c", 40),
        "status" => "evaluated-winner"
      },
      "change" => %{
        "repository" => context.repository,
        "repository_profile" => "loadout",
        "base_state" => %{"ref" => "main", "commit" => context.base_commit},
        "current_state" => %{
          "commit" => context.base_commit,
          "workspace_state_digest" => "sha256:producer-state"
        },
        "changed_files" => ["README.md"],
        "patch_digest" => context.state.patch_digest,
        "workspace_state" => %{"clean" => false, "status_entries" => [" M README.md"]}
      },
      "affected_surfaces" => ["documentation"],
      "claims_at_risk" => ["patch is clean"],
      "proof_obligations" => [obligation],
      "selected_verification" => [command],
      "skipped_verification" => [],
      "unknowns" => []
    }

    digest = Change.digest(change)

    envelope = %{
      "schema" => "engineering-system/work-envelope/v0",
      "work_id" => work_id,
      "created_at" => @now,
      "producer" => %{"product" => "loadout", "version" => "0.1.0"},
      "goal" => %{"title" => "Verify this change", "success_conditions" => ["truth"]},
      "capability" => %{
        "id" => "verify-change",
        "contract_version" => "0.1.0",
        "method_provenance" => ["verify-change/proof-obligation@1.0.0"]
      },
      "project_state" => %{
        "repository" => context.repository,
        "base_commit" => context.base_commit,
        "workspace_state_digest" => "sha256:producer-state"
      },
      "scope" => %{"included" => ["README.md"], "excluded" => []},
      "constraints" => %{"must" => ["exact"], "must_not" => ["shell"]},
      "context_refs" => ["loadout/verification-change/v0:" <> digest],
      "proof_obligations" => [Map.drop(obligation, ["required_commands"])],
      "authority_requests" => [
        %{"capability" => "git.read", "scope" => context.repository},
        %{
          "capability" => "verification.run:repo.diff-check",
          "scope" => context.repository
        }
      ]
    }

    {envelope, change}
  end

  defp host(result) do
    fn command, _opts ->
      {:ok,
       %{
         command_id: command.id,
         executable: "/usr/bin/git",
         argv: command.argv,
         cwd: command.cwd,
         timeout_ms: command.timeout_ms,
         environment_policy: "minimal-toolchain-path",
         environment_digest: "sha256:" <> String.duplicate("d", 64),
         network_policy: "not-required",
         registration_digest: command.registration_digest,
         exit_code: if(result == :pass, do: 0, else: 1),
         signal: 0,
         timed_out: false,
         duration_ms: 1,
         stdout: if(result == :pass, do: "ok\n", else: ""),
         stderr: if(result == :fail, do: "failed\n", else: ""),
         result: result
       }}
    end
  end

  defp git!(repository, args) do
    {output, 0} = System.cmd("git", args, cd: repository, stderr_to_stdout: true)
    output
  end
end
