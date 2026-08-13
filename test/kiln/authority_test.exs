defmodule Kiln.AuthorityTest do
  use ExUnit.Case, async: true

  alias Kiln.{Authority, RepositoryObservation}

  defp observation(repository, current_commit, head_resolved \\ true) do
    %RepositoryObservation{
      repository: repository,
      current_commit: current_commit,
      repository_state_digest: "sha256:observed",
      input_state_digest: "sha256:producer",
      observed_at: "2026-08-13T00:00:00Z",
      head_resolved: head_resolved
    }
  end

  test "grants git.read when capability, scope, and commit match" do
    repo = "/tmp/repo"
    commit = "0123456789abcdef0123456789abcdef01234567"

    assert {:ok, decision} =
             Authority.decide(
               work_id: "w1",
               run_id: "r1",
               requested_capability: "git.read",
               requested_scope: repo,
               observation: observation(repo, commit),
               base_commit: commit,
               decision_id: "d1",
               now: "2026-08-13T00:00:00Z"
             )

    assert decision.result == :granted
    assert decision.granted_scope == repo
    assert decision.reason_code == :granted
  end

  test "denies a non-git.read capability" do
    assert {:ok, decision} =
             Authority.decide(
               work_id: "w1",
               run_id: "r1",
               requested_capability: "filesystem.write",
               requested_scope: "/tmp/repo",
               observation: observation("/tmp/repo", "0123456789abcdef0123456789abcdef01234567"),
               base_commit: "0123456789abcdef0123456789abcdef01234567",
               decision_id: "d1",
               now: "2026-08-13T00:00:00Z"
             )

    assert decision.result == :denied
    assert decision.reason_code == :unsupported_capability
    assert decision.granted_scope == nil
  end

  test "denies git.read when the requested scope does not match" do
    assert {:ok, decision} =
             Authority.decide(
               work_id: "w1",
               run_id: "r1",
               requested_capability: "git.read",
               requested_scope: "/tmp/other",
               observation: observation("/tmp/repo", "0123456789abcdef0123456789abcdef01234567"),
               base_commit: "0123456789abcdef0123456789abcdef01234567",
               decision_id: "d1",
               now: "2026-08-13T00:00:00Z"
             )

    assert decision.result == :denied
    assert decision.reason_code == :scope_mismatch
  end

  test "denies git.read when the base_commit does not match the observed HEAD" do
    assert {:ok, decision} =
             Authority.decide(
               work_id: "w1",
               run_id: "r1",
               requested_capability: "git.read",
               requested_scope: "/tmp/repo",
               observation: observation("/tmp/repo", "9999999999999999999999999999999999999999"),
               base_commit: "0123456789abcdef0123456789abcdef01234567",
               decision_id: "d1",
               now: "2026-08-13T00:00:00Z"
             )

    assert decision.result == :denied
    assert decision.reason_code == :no_commit_binding
  end

  test "denies git.read when the repository HEAD could not be resolved" do
    assert {:ok, decision} =
             Authority.decide(
               work_id: "w1",
               run_id: "r1",
               requested_capability: "git.read",
               requested_scope: "/tmp/repo",
               observation: observation("/tmp/repo", nil, false),
               base_commit: "0123456789abcdef0123456789abcdef01234567",
               decision_id: "d1",
               now: "2026-08-13T00:00:00Z"
             )

    assert decision.result == :denied
    assert decision.reason_code == :head_unresolved
  end

  test "classify_requests splits granted and denied correctly" do
    commit = "0123456789abcdef0123456789abcdef01234567"

    requests = [
      %{"capability" => "git.read", "scope" => "/tmp/repo"},
      %{"capability" => "git.write", "scope" => "/tmp/repo"},
      %{"capability" => "git.read", "scope" => "/tmp/other"}
    ]

    result =
      Authority.classify_requests(requests, observation("/tmp/repo", commit), commit)

    assert length(result.granted) == 1
    assert length(result.denied) == 2
  end
end
