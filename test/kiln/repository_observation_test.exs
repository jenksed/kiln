defmodule Kiln.RepositoryObservationTest do
  use ExUnit.Case, async: true

  alias Kiln.RepositoryObservation

  setup do
    base = Path.join(System.tmp_dir!(), "kiln-repo-obs-#{System.unique_integer([:positive])}")
    File.mkdir_p!(base)
    File.write!(Path.join(base, "AGENTS.md"), "# fixture\n")
    File.write!(Path.join(base, "README.md"), "fixture readme\n")

    on_exit(fn -> File.rm_rf!(base) end)

    {:ok, base: base}
  end

  test "observes the repository root, current_commit, and digest", %{base: base} do
    System.cmd("git", ["init", "-q", "--initial-branch=main"], cd: base)
    System.cmd("git", ["config", "user.email", "test@example.com"], cd: base)
    System.cmd("git", ["config", "user.name", "Test"], cd: base)
    System.cmd("git", ["add", "."], cd: base)
    System.cmd("git", ["commit", "-m", "init"], cd: base)
    {sha, 0} = System.cmd("git", ["rev-parse", "HEAD"], cd: base)
    sha = String.trim(sha)

    assert {:ok, observation} =
             RepositoryObservation.observe(base, "sha256:input", now: "2026-08-13T00:00:00Z")

    assert observation.repository == base
    assert observation.current_commit == sha
    assert observation.head_resolved == true
    assert String.starts_with?(observation.repository_state_digest, "sha256:")
    assert observation.input_state_digest == "sha256:input"
    assert observation.observed_at == "2026-08-13T00:00:00Z"
  end

  test "returns head_resolved=false when no git HEAD is present", %{base: base} do
    assert {:ok, observation} =
             RepositoryObservation.observe(base, "sha256:input", now: "2026-08-13T00:00:00Z")

    assert observation.head_resolved == false
    assert observation.current_commit == nil
  end

  test "returns an empty manifest digest for a missing repository" do
    missing = Path.join(System.tmp_dir!(), "kiln-missing-#{System.unique_integer([:positive])}")

    assert {:ok, observation} =
             RepositoryObservation.observe(missing, "sha256:input", now: "2026-08-13T00:00:00Z")

    assert observation.head_resolved == false
    assert String.starts_with?(observation.repository_state_digest, "sha256:")
  end

  test "request_digest/1 is stable for identical observations" do
    observation = %RepositoryObservation{
      repository: "/tmp/repo",
      current_commit: "0123456789abcdef0123456789abcdef01234567",
      repository_state_digest: "sha256:abc",
      input_state_digest: "sha256:def",
      observed_at: "2026-08-13T00:00:00Z",
      head_resolved: true
    }

    assert RepositoryObservation.request_digest(observation) ==
             RepositoryObservation.request_digest(observation)
  end
end
