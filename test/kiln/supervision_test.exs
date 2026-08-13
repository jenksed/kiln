defmodule Kiln.SupervisionTest do
  use ExUnit.Case, async: false

  alias Kiln.Supervision
  alias Kiln.WorkEnvelope
  alias Kiln.Evidence.Store, as: EvidenceStore
  alias Kiln.Artifact.Store, as: ArtifactStore
  alias Kiln.Store

  @moduletag :tmp_dir

  @now "2026-08-13T00:00:00Z"

  setup do
    base = Path.join(System.tmp_dir!(), "kiln-supervision-#{System.unique_integer([:positive])}")
    File.mkdir_p!(base)

    on_exit(fn -> File.rm_rf!(base) end)

    {:ready, store} =
      Store.start(
        path: Path.join(base, "state.sqlite3"),
        store_id: "supervision_test_#{System.unique_integer([:positive])}",
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

  defp stop(conn) do
    if Process.alive?(conn), do: GenServer.stop(conn)
    :ok
  catch
    :exit, _ -> :ok
  end

  defp envelope(repo_root, base_commit) do
    %{
      "schema" => "engineering-system/work-envelope/v0",
      "work_id" => "wfg-repository-recon-#{System.unique_integer([:positive])}",
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

  describe "supervise/2 — happy path" do
    test "binds a work_id to a durable Run, persists Artifact + Evidence, and produces a Run Result Envelope",
         %{store: store, repo: repo, base_commit: base_commit} do
      attrs = envelope(repo, base_commit)

      assert {:ok, result} =
               Supervision.supervise(attrs,
                 store: store,
                 actor_id: "test-actor",
                 now: @now,
                 git: "git",
                 observation_completion: %{
                   status: :completed,
                   warnings: [],
                   unknowns: []
                 }
               )

      assert result.work_id == attrs["work_id"]
      assert result.run_id != nil
      assert result.status == :completed
      assert result.authority.granted == ["git.read"]
      assert result.authority.denied == []
      assert result.proof_obligations.satisfied == ["repo-state-observed"]
      assert result.acceptance_readiness.ready == false
      refute Enum.empty?(result.effects)

      assert [
               %{
                 "id" => evidence_id,
                 "kind" => "evidence",
                 "state_digest" => "sha256:" <> _digest
               }
             ] = result.evidence

      assert is_binary(evidence_id)
    end

    test "replay: same work_id + same request returns the same Run identity",
         %{store: store, repo: repo, base_commit: base_commit} do
      attrs = envelope(repo, base_commit)
      attrs = Map.put(attrs, "work_id", "wfg-replay-#{System.unique_integer([:positive])}")

      assert {:ok, first} = Supervision.supervise(attrs, default_opts(store))
      assert {:ok, second} = Supervision.supervise(attrs, default_opts(store))

      assert first.run_id == second.run_id
      assert first.work_id == second.work_id
    end

    test "conflict: same work_id + different request returns idempotency conflict",
         %{store: store, repo: repo, base_commit: base_commit} do
      work_id = "wfg-conflict-#{System.unique_integer([:positive])}"
      attrs_a = Map.put(envelope(repo, base_commit), "work_id", work_id)

      assert {:ok, _} = Supervision.supervise(attrs_a, default_opts(store))

      attrs_b =
        attrs_a
        |> Map.put("goal", %{
          "title" => "Materially different goal",
          "success_conditions" => ["report something else"]
        })

      assert {:error, {:idempotency_conflict, _, _}} =
               Supervision.supervise(attrs_b, default_opts(store))
    end
  end

  describe "authority v0 — git.read only" do
    test "denies a non-git.read capability request and blocks the run",
         %{store: store, repo: repo, base_commit: base_commit} do
      attrs =
        envelope(repo, base_commit)
        |> Map.put("work_id", "wfg-denied-#{System.unique_integer([:positive])}")
        |> put_in(["authority_requests"], [
          %{"capability" => "filesystem.write", "scope" => repo}
        ])

      assert {:ok, blocked} = Supervision.supervise(attrs, default_opts(store))
      assert blocked.status == :blocked
      assert blocked.authority.requested == ["filesystem.write"]
      assert blocked.authority.granted == []
      assert blocked.authority.denied == ["filesystem.write"]
      assert blocked.proof_obligations.unsatisfied == ["repo-state-observed"]
    end
  end

  describe "procedure failure after grant" do
    test "does not manufacture success when observation completion reports failure",
         %{store: store, repo: repo, base_commit: base_commit} do
      attrs =
        envelope(repo, base_commit)
        |> Map.put("work_id", "wfg-procfail-#{System.unique_integer([:positive])}")

      assert {:ok, result} =
               Supervision.supervise(attrs,
                 store: store,
                 actor_id: "test-actor",
                 now: @now,
                 git: "git",
                 observation_completion: %{
                   status: :failed,
                   warnings: ["procedure errored"],
                   unknowns: []
                 }
               )

      assert result.status == :failed
      refute result.proof_obligations.satisfied == ["repo-state-observed"]
    end
  end

  describe "state change between observation and Evidence evaluation" do
    test "evaluates the recorded Evidence against the supplied context and reports stale when state changed",
         %{store: store, repo: repo, base_commit: base_commit} do
      attrs =
        envelope(repo, base_commit)
        |> Map.put("work_id", "wfg-statechange-#{System.unique_integer([:positive])}")

      assert {:ok, _result} = Supervision.supervise(attrs, default_opts(store))

      {digest, _} = compute_envelope_digest(attrs)

      {:ok, current_run_id} = Supervision.lookup_run(store, attrs["work_id"], digest)

      # Fetch the evidence row directly to ensure the Evidence substrate
      # exists and is immutable.
      artifact_rows =
        Store.Connection.query!(
          store.conn,
          "SELECT evidence_id FROM supervision_run_evidence WHERE run_id = ?1",
          [current_run_id]
        )

      [[evidence_id]] = artifact_rows

      # The Evidence was recorded against the observed digest. A
      # currentness evaluation against a *different* repository_state_digest
      # must classify the Evidence as stale, not silently current.
      evidence = fetch_evidence(store, evidence_id)

      {:ok, ctx} =
        Kiln.Evidence.Currentness.Context.new(%{
          current_subject_state_digest: "sha256:changed-subject",
          current_repository_state_digest: "sha256:different-repository",
          current_evaluator_digest: evidence.evaluator_digest,
          artifact_integrity_by_id: Map.new(evidence.artifact_ids, &{&1, :verified}),
          evaluated_at: @now
        })

      {:ok, views} = Kiln.Evidence.Currentness.evaluate([evidence], ctx)
      assert [%{freshness: :stale}] = views
    end
  end

  describe "restart durability" do
    test "the durable facts survive a store close-and-reopen cycle",
         %{store: store, repo: repo, base: base, base_commit: base_commit} do
      attrs =
        envelope(repo, base_commit)
        |> Map.put("work_id", "wfg-restart-#{System.unique_integer([:positive])}")

      assert {:ok, first} = Supervision.supervise(attrs, default_opts(store))

      GenServer.stop(store.conn)
      Process.sleep(50)

      {:ready, reopened} =
        Store.start(
          path: Path.join(base, "state.sqlite3"),
          store_id: "reopened_store_#{System.unique_integer([:positive])}",
          now: @now
        )

      assert reopened.store_version == store.store_version

      assert {:ok, reconstructed} = Supervision.inspect_run(reopened, first.run_id)
      assert reconstructed.run_id == first.run_id
      assert reconstructed.work_id == first.work_id
      assert reconstructed.schema == "engineering-system/run-result-envelope/v0"
    end
  end

  describe "load-bearing Artifact and Evidence" do
    test "the persisted Artifact bytes can be fetched after the run",
         %{store: store, repo: repo, base_commit: base_commit} do
      attrs =
        envelope(repo, base_commit)
        |> Map.put("work_id", "wfg-artifact-#{System.unique_integer([:positive])}")

      assert {:ok, result} = Supervision.supervise(attrs, default_opts(store))

      {digest, _} = compute_envelope_digest(attrs)
      {:ok, current_run_id} = Supervision.lookup_run(store, attrs["work_id"], digest)

      assert current_run_id == result.run_id

      [[artifact_id]] =
        Store.Connection.query!(
          store.conn,
          "SELECT artifact_id FROM supervision_run_artifacts WHERE run_id = ?1 ORDER BY position LIMIT 1",
          [result.run_id]
        )

      assert {:ok, _artifact, %{integrity_status: :verified}} =
               ArtifactStore.fetch(store, artifact_id)
    end
  end

  defp default_opts(store) do
    [
      store: store,
      actor_id: "test-actor",
      now: @now,
      git: "git",
      observation_completion: %{
        status: :completed,
        warnings: [],
        unknowns: []
      }
    ]
  end

  defp fetch_evidence(store, evidence_id) do
    {:ok, evidence, _integrity} = EvidenceStore.fetch(store, evidence_id)
    evidence
  end

  defp compute_envelope_digest(attrs) do
    {:ok, envelope} = WorkEnvelope.new(attrs)
    {WorkEnvelope.request_digest(envelope), envelope}
  end
end
