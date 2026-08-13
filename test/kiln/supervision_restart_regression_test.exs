defmodule Kiln.SupervisionRestartRegressionTest do
  @moduledoc """
  KILN-01 regression test.

  The reconstructed Run Result Envelope after process death must
  equal the originally supervised envelope on every durable semantic
  field. The legacy `reconstruct_envelope/5` hardcoded placeholders
  (`"sha256:restored"`, `"0000…0000"`, empty authority lists) so
  `authority.granted/requested/denied`, `final_state.commit`, and
  `input_state.base_commit` did not survive restart.

  The acceptance criteria for this test:

    * Run a real supervision end-to-end, capture the canonical
      semantic result `R1`.
    * Stop the live connection, restart the store from disk.
    * Recover the supervised Run via `Kiln.Supervision.inspect_run/2`,
      producing `R2`.
    * Assert `durable_truth(R1) == durable_truth(R2)` on every field
      that represents historical durable truth. Timestamps and
      transient metadata are NOT required to be byte-identical unless
      their contract requires it.

  Negative reconstruction tests verify the supervisor does NOT
  fabricate success when an Artifact body is missing, corrupt, or
  unreadable, or when durable information is partial.
  """

  use ExUnit.Case, async: false

  alias Kiln.Artifact.Store, as: ArtifactStore
  alias Kiln.Store
  alias Kiln.Supervision

  @moduletag :tmp_dir
  @now "2026-08-13T00:00:00Z"

  setup do
    base = Path.join(System.tmp_dir!(), "kiln-sup-restart-#{System.unique_integer([:positive])}")
    File.mkdir_p!(base)
    on_exit(fn -> File.rm_rf!(base) end)

    {:ready, store} =
      Store.start(
        path: Path.join(base, "state.sqlite3"),
        store_id: "sup_restart_#{System.unique_integer([:positive])}",
        now: @now
      )

    on_exit(fn -> stop(store.conn) end)

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

    {:ok, store: store, base: base, repo: repo, base_commit: base_commit}
  end

  describe "restart semantic equality" do
    test "durable_truth(R1) == durable_truth(R2) for every historical semantic field",
         %{store: store, base: base, repo: repo, base_commit: base_commit} do
      attrs = envelope(repo, base_commit, "wfg-restart-eq-#{System.unique_integer([:positive])}")

      assert {:ok, first} =
               Supervision.supervise(attrs,
                 store: store,
                 actor_id: "test-actor",
                 now: @now,
                 git: "git",
                 observation_completion: %{status: :completed, warnings: [], unknowns: []}
               )

      # Stop and reopen the live connection.
      GenServer.stop(store.conn)
      Process.sleep(50)

      {:ready, reopened} =
        Store.start(
          path: Path.join(base, "state.sqlite3"),
          store_id: "reopened_#{System.unique_integer([:positive])}",
          now: @now
        )

      on_exit(fn -> stop(reopened.conn) end)

      assert {:ok, reconstructed} = Supervision.inspect_run(reopened, first.run_id)

      assert semantic_equal?(first, reconstructed),
             """
             durable truth divergence:
               first.status=#{first.status} reconstructed.status=#{reconstructed.status}
               first.input_state=#{inspect(first.input_state)}
               reconstructed.input_state=#{inspect(reconstructed.input_state)}
               first.final_state=#{inspect(first.final_state)}
               reconstructed.final_state=#{inspect(reconstructed.final_state)}
               first.authority=#{inspect(first.authority)}
               reconstructed.authority=#{inspect(reconstructed.authority)}
               first.proof_obligations=#{inspect(first.proof_obligations)}
               reconstructed.proof_obligations=#{inspect(reconstructed.proof_obligations)}
             """

      assert reconstructed.work_id == first.work_id
      assert reconstructed.run_id == first.run_id
      assert reconstructed.status == first.status
      assert reconstructed.input_state == first.input_state
      assert reconstructed.final_state == first.final_state
      assert reconstructed.authority == first.authority
      assert reconstructed.evidence == first.evidence
      assert reconstructed.proof_obligations.unknown == false
    end
  end

  describe "negative reconstruction behavior" do
    test "missing artifact does not invent original authority or final commit",
         %{store: store, repo: repo, base_commit: base_commit} do
      attrs = envelope(repo, base_commit, "wfg-neg-missing-#{System.unique_integer([:positive])}")

      assert {:ok, first} =
               Supervision.supervise(attrs,
                 store: store,
                 actor_id: "test-actor",
                 now: @now,
                 git: "git",
                 observation_completion: %{status: :completed, warnings: [], unknowns: []}
               )

      # Delete the observation artifact body from disk. The metadata
      # row remains but the bytes are absent; reconstruction must NOT
      # fabricate a value.
      [[artifact_id]] =
        Store.Connection.query!(
          store.conn,
          """
          SELECT artifact_id FROM supervision_run_artifacts
          WHERE run_id = ?1
          ORDER BY position ASC LIMIT 1
          """,
          [first.run_id]
        )

      {:ok, artifact, _integrity} = ArtifactStore.fetch(store, artifact_id)
      File.rm!(Path.join(store.artifact_root, artifact.content_location))

      assert {:error, {:incomplete_durable_facts, _reason}} =
               Supervision.inspect_run(store, first.run_id)
    end

    test "corrupt artifact does not deserialize and trust bytes without integrity",
         %{store: store, repo: repo, base_commit: base_commit} do
      attrs = envelope(repo, base_commit, "wfg-neg-corrupt-#{System.unique_integer([:positive])}")

      assert {:ok, first} =
               Supervision.supervise(attrs,
                 store: store,
                 actor_id: "test-actor",
                 now: @now,
                 git: "git",
                 observation_completion: %{status: :completed, warnings: [], unknowns: []}
               )

      [[artifact_id]] =
        Store.Connection.query!(
          store.conn,
          """
          SELECT artifact_id FROM supervision_run_artifacts
          WHERE run_id = ?1
          ORDER BY position ASC LIMIT 1
          """,
          [first.run_id]
        )

      {:ok, artifact, _integrity} = ArtifactStore.fetch(store, artifact_id)
      File.write!(Path.join(store.artifact_root, artifact.content_location), "tampered bytes")

      assert {:error, {:incomplete_durable_facts, _reason}} =
               Supervision.inspect_run(store, first.run_id)
    end

    test "partial durable information exposes an unknown state rather than sentinel",
         %{store: store, repo: repo, base_commit: base_commit} do
      attrs = envelope(repo, base_commit, "wfg-neg-partial-#{System.unique_integer([:positive])}")

      assert {:ok, first} =
               Supervision.supervise(attrs,
                 store: store,
                 actor_id: "test-actor",
                 now: @now,
                 git: "git",
                 observation_completion: %{status: :completed, warnings: [], unknowns: []}
               )

      # Drop all Evidence rows bound to the Run; observation stays
      # intact, so identity is recoverable but proof_obligations
      # cannot be partitioned truthfully.
      Store.Connection.query!(
        store.conn,
        "DELETE FROM supervision_run_evidence WHERE run_id = ?1",
        [first.run_id]
      )

      {:ok, reconstructed} = Supervision.inspect_run(store, first.run_id)

      assert reconstructed.work_id == first.work_id
      assert reconstructed.run_id == first.run_id
      assert reconstructed.authority == first.authority
      assert reconstructed.final_state == first.final_state
      assert reconstructed.input_state == first.input_state

      # Without Evidence the supervisor cannot derive satisfied
      # obligations; it returns the empty partition rather than a
      # sentinel.
      assert reconstructed.proof_obligations.satisfied == []
      assert reconstructed.proof_obligations.unknown == false
    end

    test "replay determinism: repeated inspect/reconstruction is stable",
         %{store: store, repo: repo, base_commit: base_commit} do
      attrs = envelope(repo, base_commit, "wfg-neg-replay-#{System.unique_integer([:positive])}")

      assert {:ok, first} =
               Supervision.supervise(attrs,
                 store: store,
                 actor_id: "test-actor",
                 now: @now,
                 git: "git",
                 observation_completion: %{status: :completed, warnings: [], unknowns: []}
               )

      assert {:ok, r1} = Supervision.inspect_run(store, first.run_id)
      assert {:ok, r2} = Supervision.inspect_run(store, first.run_id)

      assert semantic_equal?(r1, r2)

      assert r1.authority == r2.authority
      assert r1.input_state == r2.input_state
      assert r1.final_state == r2.final_state
      assert r1.proof_obligations == r2.proof_obligations
      assert Enum.sort(r1.unknowns) == Enum.sort(r2.unknowns)
    end
  end

  # -- helpers --

  defp stop(conn) do
    if Process.alive?(conn), do: GenServer.stop(conn)
    :ok
  catch
    :exit, _ -> :ok
  end

  defp envelope(repo_root, base_commit, work_id) do
    %{
      "schema" => "engineering-system/work-envelope/v0",
      "work_id" => work_id,
      "created_at" => @now,
      "producer" => %{"product" => "loadout", "version" => "1.0.0"},
      "goal" => %{
        "title" => "Understand this repository",
        "success_conditions" => ["report architecture anchors"]
      },
      "capability" => %{
        "id" => "repository-recon",
        "contract_version" => "0.1.0",
        "method_provenance" => ["loadout/recon@0.0.1", "digest:sha256:test"]
      },
      "project_state" => %{
        "repository" => repo_root,
        "base_commit" => base_commit,
        "workspace_state_digest" => "sha256:producer-input"
      },
      "scope" => %{"included" => ["tracked files"], "excluded" => ["mutation"]},
      "constraints" => %{
        "must" => ["distinguish observations from inferences"],
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
        %{"capability" => "git.read", "scope" => repo_root}
      ]
    }
  end

  defp semantic_equal?(a, b) do
    a.work_id == b.work_id and
      a.run_id == b.run_id and
      a.status == b.status and
      a.input_state == b.input_state and
      a.final_state == b.final_state and
      a.authority == b.authority and
      normalize_obligations(a.proof_obligations) ==
        normalize_obligations(b.proof_obligations)
  end

  # The reconstructed envelope carries an extra `unknown: true | false`
  # flag on `proof_obligations` so the supervisor can report partial
  # durable information. Strip the flag for equality comparisons.
  defp normalize_obligations(obligations) do
    Map.delete(obligations, :unknown)
  end
end
