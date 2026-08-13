defmodule Kiln.Evidence.ViewTest do
  @moduledoc """
  Unit tests for `Kiln.Evidence.View` and its first-month conformance
  projection (P1-S02-T01-R07, AC05).
  """

  use ExUnit.Case, async: true

  alias Kiln.Evidence
  alias Kiln.Evidence.Currentness
  alias Kiln.Evidence.View

  defp base_evidence_attrs(overrides) do
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

  defp build_view(overrides) do
    {:ok, evidence} = Evidence.new(base_evidence_attrs(overrides))

    {:ok, context} =
      Currentness.Context.new(%{
        current_subject_state_digest: evidence.subject_state_digest,
        current_repository_state_digest: evidence.repository_state_digest,
        current_evaluator_digest: evidence.evaluator_digest,
        evaluated_at: "2026-08-12T00:00:02Z"
      })

    {:ok, [view]} = Currentness.evaluate([evidence], context)
    view
  end

  describe "to_first_month/1" do
    test "emits the exact conformance subset (AC05, R07)" do
      view =
        build_view(%{
          result: :pass,
          completeness: :complete
        })

      projection = View.to_first_month(view)

      assert projection == %{
               kind: :evidence,
               evidence_id: view.evidence_id,
               criterion_id: view.criterion_id,
               status: :pass,
               freshness: :current,
               completeness: :complete,
               contradiction: :none,
               repository_state_digest: view.repository_state_digest,
               record_digest: view.record_digest
             }
    end

    test "emits exactly nine keys" do
      projection =
        build_view(%{})
        |> View.to_first_month()

      assert Map.keys(projection) |> Enum.sort() == [
               :completeness,
               :contradiction,
               :criterion_id,
               :evidence_id,
               :freshness,
               :kind,
               :record_digest,
               :repository_state_digest,
               :status
             ]
    end

    test "maps stored :fail result to :status without mutating the view" do
      view = build_view(%{result: :fail, completeness: :complete})
      assert view.status == :fail

      projection = View.to_first_month(view)
      assert projection.status == :fail
      assert view.status == :fail
    end

    test "preserves stale freshness and unknown contradiction unchanged" do
      evidence =
        Evidence.new(
          base_evidence_attrs(%{
            result: :blocked,
            completeness: :partial,
            repository_state_digest: "old-repo-digest"
          })
        )
        |> elem(1)

      {:ok, context} =
        Currentness.Context.new(%{
          current_subject_state_digest: evidence.subject_state_digest,
          current_repository_state_digest: "new-repo-digest",
          current_evaluator_digest: evidence.evaluator_digest,
          evaluated_at: "2026-08-12T00:00:02Z"
        })

      {:ok, [view]} = Currentness.evaluate([evidence], context)
      projection = View.to_first_month(view)

      assert projection.freshness == :stale
      assert projection.contradiction == :unknown
      assert projection.status == :blocked
    end
  end
end
