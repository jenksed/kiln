defmodule Kiln.Evidence.RecordRequestTest do
  use ExUnit.Case, async: true

  alias Kiln.Evidence
  alias Kiln.Evidence.RecordRequest

  defp base_evidence_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        evidence_id: "01900000-0000-7000-8000-000000000000",
        session_id: "session-1",
        run_id: "run-1",
        criterion_id: "criterion-1",
        criterion_revision: "v1",
        subject_id: "subject-1",
        subject_kind: :repository,
        subject_state_digest: "subject-digest",
        producer_kind: :deterministic_service,
        producer_id: "producer-1",
        method: :repository_observation,
        result: :pass,
        repository_state_digest: "repo-digest",
        artifact_ids: [],
        evaluator_digest: "eval-digest",
        observation_digest: "obs-digest",
        completeness: :complete,
        freshness_rule: :same_repository_state,
        observed_at: "2026-08-12T00:00:00Z",
        recorded_at: "2026-08-12T00:00:01Z",
        idempotency_key: "idem-1"
      },
      overrides
    )
  end

  defp assert_precondition(error, code) do
    assert %Kiln.Store.Error{class: :precondition, code: ^code} = error
  end

  describe "new/1 — happy paths" do
    test "constructs a minimal RecordRequest" do
      attrs = %{evidence: base_evidence_attrs()}
      assert {:ok, request} = RecordRequest.new(attrs)
      assert %Evidence{} = request.evidence
      assert request.admission_context == nil
      assert request.warnings == []
    end

    test "accepts an admission_context" do
      ctx = %{
        current_subject_state_digest: "subject-digest",
        current_repository_state_digest: "repo-digest",
        current_evaluator_digest: "eval-digest"
      }

      attrs = %{evidence: base_evidence_attrs(), admission_context: ctx}
      assert {:ok, request} = RecordRequest.new(attrs)
      assert request.admission_context == ctx
    end

    test "accepts bounded warnings" do
      attrs = %{
        evidence: base_evidence_attrs(%{result: :blocked, completeness: :partial}),
        warnings: ["first warning", "second warning"]
      }

      assert {:ok, request} = RecordRequest.new(attrs)
      assert request.warnings == ["first warning", "second warning"]
    end
  end

  describe "new/1 — missing evidence" do
    test "rejects when evidence is missing" do
      assert {:error, e} = RecordRequest.new(%{})
      assert_precondition(e, :missing_field)
    end

    test "rejects when evidence is not a map" do
      assert {:error, e} = RecordRequest.new(%{evidence: "not-a-map"})
      assert_precondition(e, :missing_field)
    end
  end

  describe "new/1 — warnings bounds" do
    test "rejects non-list warnings" do
      attrs = %{evidence: base_evidence_attrs(), warnings: "not a list"}
      assert {:error, e} = RecordRequest.new(attrs)
      assert_precondition(e, :wrong_type)
    end

    test "rejects non-binary warnings" do
      attrs = %{evidence: base_evidence_attrs(), warnings: ["ok", :not_binary]}
      assert {:error, e} = RecordRequest.new(attrs)
      assert_precondition(e, :wrong_type)
    end

    test "rejects empty warning strings" do
      attrs = %{
        evidence: base_evidence_attrs(%{result: :blocked, completeness: :partial}),
        warnings: [""]
      }

      assert {:error, e} = RecordRequest.new(attrs)
      assert_precondition(e, :empty_text)
    end

    test "rejects warnings over 1024 bytes each" do
      attrs = %{
        evidence: base_evidence_attrs(%{result: :blocked, completeness: :partial}),
        warnings: [String.duplicate("a", 1025)]
      }

      assert {:error, e} = RecordRequest.new(attrs)
      assert_precondition(e, :limit_exceeded)
    end

    test "rejects aggregate over 16384 bytes (before reaching the SQL trigger)" do
      warnings = for _ <- 1..17, do: String.duplicate("a", 1024)

      attrs = %{
        evidence: base_evidence_attrs(%{result: :blocked, completeness: :partial}),
        warnings: warnings
      }

      assert {:error, e} = RecordRequest.new(attrs)
      assert_precondition(e, :limit_exceeded)
    end

    test "accepts exactly 16384 aggregate bytes" do
      warnings =
        [String.duplicate("a", 1024)] ++
          for _ <- 1..15, do: String.duplicate("b", 1024)

      attrs = %{
        evidence: base_evidence_attrs(%{result: :blocked, completeness: :partial}),
        warnings: warnings
      }

      assert {:ok, request} = RecordRequest.new(attrs)
      assert length(request.warnings) == 16
    end

    test "rejects more than 64 warning entries" do
      warnings = for _ <- 1..65, do: "x"

      attrs = %{
        evidence: base_evidence_attrs(%{result: :blocked, completeness: :partial}),
        warnings: warnings
      }

      assert {:error, e} = RecordRequest.new(attrs)
      assert_precondition(e, :limit_exceeded)
    end

    test "accepts exactly 64 warning entries" do
      warnings = for _ <- 1..64, do: "x"

      attrs = %{
        evidence: base_evidence_attrs(%{result: :blocked, completeness: :partial}),
        warnings: warnings
      }

      assert {:ok, request} = RecordRequest.new(attrs)
      assert length(request.warnings) == 64
    end
  end

  describe "new/1 — admission_context validation" do
    test "rejects non-map admission_context" do
      attrs = %{evidence: base_evidence_attrs(), admission_context: "not-a-map"}
      assert {:error, e} = RecordRequest.new(attrs)
      assert_precondition(e, :wrong_type)
    end

    test "rejects admission_context with unknown fields" do
      ctx = %{
        current_subject_state_digest: "subject-digest",
        current_unknown_field: "value"
      }

      attrs = %{evidence: base_evidence_attrs(), admission_context: ctx}
      assert {:error, e} = RecordRequest.new(attrs)
      assert_precondition(e, :unknown_field)
    end

    test "accepts a complete admission_context" do
      ctx = %{
        current_subject_state_digest: "subject-digest",
        current_repository_state_digest: "repo-digest",
        current_patch_id: nil,
        current_patch_digest: nil,
        current_patch_result_digest: nil,
        current_host_profile_digest: nil,
        current_command_registration_digest: nil,
        current_command_result_id: nil,
        current_evaluator_digest: "eval-digest",
        invalidated_at: nil,
        evaluated_at: "2026-08-12T00:00:00Z",
        artifact_integrity_by_id: %{}
      }

      attrs = %{evidence: base_evidence_attrs(), admission_context: ctx}
      assert {:ok, _} = RecordRequest.new(attrs)
    end
  end
end
