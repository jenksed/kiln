defmodule Kiln.RunResultEnvelopeTest do
  use ExUnit.Case, async: true

  alias Kiln.{Authority, RepositoryObservation, RunResultEnvelope}

  defp observation do
    %RepositoryObservation{
      repository: "/tmp/repo",
      current_commit: "0123456789abcdef0123456789abcdef01234567",
      repository_state_digest: "sha256:observed",
      input_state_digest: "sha256:producer",
      observed_at: "2026-08-13T00:00:00Z",
      head_resolved: true
    }
  end

  defp granted_decision do
    {:ok, decision} =
      Authority.decide(
        work_id: "w1",
        run_id: "r1",
        requested_capability: "git.read",
        requested_scope: "/tmp/repo",
        observation: observation(),
        base_commit: "0123456789abcdef0123456789abcdef01234567",
        decision_id: "d1",
        now: "2026-08-13T00:00:00Z"
      )

    decision
  end

  defp denied_decision do
    {:ok, decision} =
      Authority.decide(
        work_id: "w1",
        run_id: "r1",
        requested_capability: "filesystem.write",
        requested_scope: "/tmp/repo",
        observation: observation(),
        base_commit: "0123456789abcdef0123456789abcdef01234567",
        decision_id: "d2",
        now: "2026-08-13T00:00:00Z"
      )

    decision
  end

  test "builds a successful envelope with the requested, granted, and denied authority sets" do
    decisions = [granted_decision(), denied_decision()]

    assert {:ok, envelope} =
             RunResultEnvelope.build(
               work_id: "w1",
               run_id: "r1",
               status: :completed,
               input_state: %{
                 base_commit: "0123456789abcdef0123456789abcdef01234567",
                 workspace_state_digest: "sha256:producer"
               },
               final_state: %{
                 commit: "0123456789abcdef0123456789abcdef01234567",
                 workspace_state_digest: "sha256:producer"
               },
               authority_decisions: decisions,
               effects: [],
               evidence: [],
               proof_obligations: %{
                 satisfied: ["repo-state-observed"],
                 unsatisfied: [],
                 invalidated: []
               },
               unknowns: []
             )

    assert envelope.work_id == "w1"
    assert envelope.run_id == "r1"
    assert envelope.status == :completed
    assert envelope.authority.granted == ["git.read"]
    assert envelope.authority.denied == ["filesystem.write"]
    assert envelope.authority.requested == Enum.sort(["git.read", "filesystem.write"])
    assert envelope.acceptance_readiness.ready == false
    refute Enum.empty?(envelope.acceptance_readiness.reasons)
  end

  test "rejects an invalid status" do
    assert {:error, {:invalid_status, _}} =
             RunResultEnvelope.build(
               work_id: "w1",
               run_id: "r1",
               status: :weird,
               input_state: %{
                 base_commit: "0123456789abcdef0123456789abcdef01234567",
                 workspace_state_digest: "sha256:producer"
               },
               final_state: %{
                 commit: "0123456789abcdef0123456789abcdef01234567",
                 workspace_state_digest: "sha256:producer"
               },
               authority_decisions: [granted_decision()],
               effects: [],
               evidence: [],
               proof_obligations: %{},
               unknowns: []
             )
  end

  test "rejects malformed input_state" do
    assert {:error, :invalid_input_state} =
             RunResultEnvelope.build(
               work_id: "w1",
               run_id: "r1",
               status: :completed,
               input_state: %{base_commit: "", workspace_state_digest: "x"},
               final_state: %{
                 commit: "0123456789abcdef0123456789abcdef01234567",
                 workspace_state_digest: "sha256:producer"
               },
               authority_decisions: [granted_decision()],
               effects: [],
               evidence: [],
               proof_obligations: %{},
               unknowns: []
             )
  end

  test "to_map/1 produces a JSON-friendly map keyed by strings" do
    assert {:ok, envelope} =
             RunResultEnvelope.build(
               work_id: "w1",
               run_id: "r1",
               status: :completed,
               input_state: %{
                 base_commit: "0123456789abcdef0123456789abcdef01234567",
                 workspace_state_digest: "sha256:producer"
               },
               final_state: %{
                 commit: "0123456789abcdef0123456789abcdef01234567",
                 workspace_state_digest: "sha256:producer"
               },
               authority_decisions: [granted_decision()],
               effects: [],
               evidence: [],
               proof_obligations: %{},
               unknowns: []
             )

    map = RunResultEnvelope.to_map(envelope)
    assert map["schema"] == "engineering-system/run-result-envelope/v0"
    assert map["work_id"] == "w1"
    assert map["status"] == "completed"
    assert map["recovery"] == nil
    assert map["acceptance_readiness"]["ready"] == false
  end
end
