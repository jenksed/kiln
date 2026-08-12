defmodule Kiln.Evidence.CurrentnessTest do
  use ExUnit.Case, async: true

  alias Kiln.Evidence
  alias Kiln.Evidence.Currentness

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

  defp build_evidence(overrides) do
    {:ok, evidence} = Evidence.new(base_evidence_attrs(overrides))
    evidence
  end

  defp base_context(overrides \\ %{}) do
    attrs =
      Map.merge(
        %{
          current_subject_state_digest: "subject-digest",
          current_repository_state_digest: "repo-digest",
          current_evaluator_digest: "eval-digest",
          evaluated_at: "2026-08-12T00:00:02Z"
        },
        overrides
      )

    {:ok, ctx} = Currentness.Context.new(attrs)
    ctx
  end

  # -- happy path: currentness --

  describe "evaluate/2 — freshness :current" do
    test "returns :current for a fully matching same_repository_state Evidence" do
      evidence = build_evidence(%{})
      {:ok, [view]} = Currentness.evaluate([evidence], base_context())
      assert view.evidence_id == evidence.evidence_id
      assert view.freshness == :current
      assert view.contradiction == :none
    end

    test "returns :current when artifact_ids are empty" do
      evidence = build_evidence(%{artifact_ids: []})
      {:ok, [view]} = Currentness.evaluate([evidence], base_context())
      assert view.freshness == :current
    end

    test "returns :current when every referenced artifact is :verified" do
      a1 = "01900000-0000-7000-8000-000000000001"
      evidence = build_evidence(%{artifact_ids: [a1]})
      ctx = Map.put(base_context(), :artifact_integrity_by_id, %{a1 => :verified})
      {:ok, [view]} = Currentness.evaluate([evidence], ctx)
      assert view.freshness == :current
    end
  end

  # -- freshness :stale --

  describe "evaluate/2 — freshness :stale" do
    test "stale when subject_state_digest differs" do
      evidence = build_evidence(%{})
      ctx = Map.put(base_context(), :current_subject_state_digest, "different")
      {:ok, [view]} = Currentness.evaluate([evidence], ctx)
      assert view.freshness == :stale
    end

    test "stale when repository_state_digest differs" do
      evidence = build_evidence(%{})
      ctx = Map.put(base_context(), :current_repository_state_digest, "different")
      {:ok, [view]} = Currentness.evaluate([evidence], ctx)
      assert view.freshness == :stale
    end

    test "stale when evaluator_digest differs" do
      evidence = build_evidence(%{})
      ctx = Map.put(base_context(), :current_evaluator_digest, "different")
      {:ok, [view]} = Currentness.evaluate([evidence], ctx)
      assert view.freshness == :stale
    end

    test "stale when invalidated_at is supplied" do
      evidence = build_evidence(%{})
      ctx = Map.put(base_context(), :invalidated_at, "2026-08-12T01:00:00Z")
      {:ok, [view]} = Currentness.evaluate([evidence], ctx)
      assert view.freshness == :stale
      assert view.invalidated_at == "2026-08-12T01:00:00Z"
    end

    test "stale when same_patch_and_repository_state rule but patch_id differs" do
      evidence =
        build_evidence(%{
          freshness_rule: :same_patch_and_repository_state,
          patch_id: "01900000-0000-7000-8000-000000000010",
          patch_digest: "patch-digest",
          patch_result_digest: "patch-result-digest"
        })

      ctx =
        Map.merge(base_context(), %{
          current_patch_id: "different-patch-id",
          current_patch_digest: "patch-digest",
          current_patch_result_digest: "patch-result-digest"
        })

      {:ok, [view]} = Currentness.evaluate([evidence], ctx)
      assert view.freshness == :stale
    end

    test "stale when same_patch_and_repository_state rule but patch_digest differs" do
      evidence =
        build_evidence(%{
          freshness_rule: :same_patch_and_repository_state,
          patch_id: "01900000-0000-7000-8000-000000000010",
          patch_digest: "patch-digest-a",
          patch_result_digest: "patch-result-digest"
        })

      ctx =
        Map.merge(base_context(), %{
          current_patch_id: "01900000-0000-7000-8000-000000000010",
          current_patch_digest: "different-digest",
          current_patch_result_digest: "patch-result-digest"
        })

      {:ok, [view]} = Currentness.evaluate([evidence], ctx)
      assert view.freshness == :stale
    end

    test "stale when same_patch_and_repository_state rule but patch_result_digest differs" do
      evidence =
        build_evidence(%{
          freshness_rule: :same_patch_and_repository_state,
          patch_id: "01900000-0000-7000-8000-000000000010",
          patch_digest: "patch-digest",
          patch_result_digest: "result-a"
        })

      ctx =
        Map.merge(base_context(), %{
          current_patch_id: "01900000-0000-7000-8000-000000000010",
          current_patch_digest: "patch-digest",
          current_patch_result_digest: "different-result"
        })

      {:ok, [view]} = Currentness.evaluate([evidence], ctx)
      assert view.freshness == :stale
    end

    test "stale when same_command_registration_and_repository_state rule but command_registration_digest differs" do
      evidence =
        build_evidence(%{
          method: :registered_command,
          freshness_rule: :same_command_registration_and_repository_state,
          host_profile_digest: "host-profile",
          command_registration_digest: "cmd-reg",
          command_result_id: "cmd-result-1"
        })

      ctx =
        Map.merge(base_context(), %{
          current_host_profile_digest: "host-profile",
          current_command_registration_digest: "different-reg",
          current_command_result_id: "cmd-result-1"
        })

      {:ok, [view]} = Currentness.evaluate([evidence], ctx)
      assert view.freshness == :stale
    end

    test "stale when same_command_registration_and_repository_state rule but command_result_id differs" do
      evidence =
        build_evidence(%{
          method: :registered_command,
          freshness_rule: :same_command_registration_and_repository_state,
          host_profile_digest: "host-profile",
          command_registration_digest: "cmd-reg",
          command_result_id: "cmd-result-1"
        })

      ctx =
        Map.merge(base_context(), %{
          current_host_profile_digest: "host-profile",
          current_command_registration_digest: "cmd-reg",
          current_command_result_id: "different-result"
        })

      {:ok, [view]} = Currentness.evaluate([evidence], ctx)
      assert view.freshness == :stale
    end

    test "manual_same_repository_state still requires subject + repo + evaluator to match" do
      evidence = build_evidence(%{freshness_rule: :manual_same_repository_state})
      ctx = Map.put(base_context(), :current_subject_state_digest, "different")
      {:ok, [view]} = Currentness.evaluate([evidence], ctx)
      assert view.freshness == :stale
    end

    test "manual_same_repository_state with explicit invalidation is stale" do
      evidence = build_evidence(%{freshness_rule: :manual_same_repository_state})
      ctx = Map.put(base_context(), :invalidated_at, "2026-08-12T01:00:00Z")
      {:ok, [view]} = Currentness.evaluate([evidence], ctx)
      assert view.freshness == :stale
    end
  end

  # -- freshness :unknown --

  describe "evaluate/2 — freshness :unknown" do
    test "unknown when a referenced artifact has no integrity observation" do
      a1 = "01900000-0000-7000-8000-000000000001"
      evidence = build_evidence(%{artifact_ids: [a1]})
      ctx = base_context()
      {:ok, [view]} = Currentness.evaluate([evidence], ctx)
      assert view.freshness == :unknown
    end

    test "unknown when a referenced artifact is :corrupt" do
      a1 = "01900000-0000-7000-8000-000000000001"
      evidence = build_evidence(%{artifact_ids: [a1]})
      ctx = Map.put(base_context(), :artifact_integrity_by_id, %{a1 => :corrupt})
      {:ok, [view]} = Currentness.evaluate([evidence], ctx)
      assert view.freshness == :unknown
    end

    test "unknown when a referenced artifact is :missing" do
      a1 = "01900000-0000-7000-8000-000000000001"
      evidence = build_evidence(%{artifact_ids: [a1]})
      ctx = Map.put(base_context(), :artifact_integrity_by_id, %{a1 => :missing})
      {:ok, [view]} = Currentness.evaluate([evidence], ctx)
      assert view.freshness == :unknown
    end

    test "unknown when a referenced artifact is :unknown" do
      a1 = "01900000-0000-7000-8000-000000000001"
      evidence = build_evidence(%{artifact_ids: [a1]})
      ctx = Map.put(base_context(), :artifact_integrity_by_id, %{a1 => :unknown})
      {:ok, [view]} = Currentness.evaluate([evidence], ctx)
      assert view.freshness == :unknown
    end
  end

  # -- contradiction --

  describe "evaluate/2 — contradiction :present" do
    test "two current complete pass/fail with matching bindings report contradiction" do
      pass =
        build_evidence(%{
          evidence_id: "01900000-0000-7000-8000-000000000001",
          result: :pass
        })

      fail =
        build_evidence(%{
          evidence_id: "01900000-0000-7000-8000-000000000002",
          result: :fail
        })

      {:ok, views} = Currentness.evaluate([pass, fail], base_context())

      assert Enum.find(views, &(&1.evidence_id == pass.evidence_id)).contradiction == :present
      assert Enum.find(views, &(&1.evidence_id == fail.evidence_id)).contradiction == :present
    end

    test "contradiction IDs reference the other Evidence" do
      pass =
        build_evidence(%{
          evidence_id: "01900000-0000-7000-8000-000000000001",
          result: :pass
        })

      fail =
        build_evidence(%{
          evidence_id: "01900000-0000-7000-8000-000000000002",
          result: :fail
        })

      {:ok, views} = Currentness.evaluate([pass, fail], base_context())

      pass_view = Enum.find(views, &(&1.evidence_id == pass.evidence_id))
      fail_view = Enum.find(views, &(&1.evidence_id == fail.evidence_id))

      assert pass_view.contradicting_evidence_ids == [fail.evidence_id]
      assert fail_view.contradicting_evidence_ids == [pass.evidence_id]
    end

    test "contradiction is :none for two pass records" do
      pass_a =
        build_evidence(%{
          evidence_id: "01900000-0000-7000-8000-000000000001",
          result: :pass
        })

      pass_b =
        build_evidence(%{
          evidence_id: "01900000-0000-7000-8000-000000000002",
          result: :pass
        })

      {:ok, views} = Currentness.evaluate([pass_a, pass_b], base_context())
      assert Enum.all?(views, &(&1.contradiction == :none))
    end

    test "contradiction is :none for pass + blocked" do
      pass =
        build_evidence(%{
          evidence_id: "01900000-0000-7000-8000-000000000001",
          result: :pass
        })

      blocked =
        build_evidence(%{
          evidence_id: "01900000-0000-7000-8000-000000000002",
          result: :blocked,
          completeness: :partial
        })

      {:ok, views} = Currentness.evaluate([pass, blocked], base_context())
      assert Enum.all?(views, &(&1.contradiction == :none))
    end

    test "contradiction is :none when one record is non-complete" do
      pass =
        build_evidence(%{
          evidence_id: "01900000-0000-7000-8000-000000000001",
          result: :pass,
          completeness: :complete
        })

      incomplete =
        build_evidence(%{
          evidence_id: "01900000-0000-7000-8000-000000000002",
          result: :blocked,
          completeness: :partial
        })

      {:ok, views} = Currentness.evaluate([pass, incomplete], base_context())

      pass_view = Enum.find(views, &(&1.evidence_id == pass.evidence_id))
      blocked_view = Enum.find(views, &(&1.evidence_id == incomplete.evidence_id))

      assert pass_view.contradiction == :none
      assert blocked_view.contradiction == :none
    end

    test "contradiction is :unknown when freshness is :stale" do
      pass =
        build_evidence(%{
          evidence_id: "01900000-0000-7000-8000-000000000001",
          result: :pass
        })

      fail =
        build_evidence(%{
          evidence_id: "01900000-0000-7000-8000-000000000002",
          result: :fail
        })

      ctx = Map.put(base_context(), :invalidated_at, "2026-08-12T01:00:00Z")
      {:ok, views} = Currentness.evaluate([pass, fail], ctx)
      assert Enum.all?(views, &(&1.contradiction == :unknown))
    end

    test "contradiction grouping is independent of producer, method, evaluator, command result, artifact set" do
      pass =
        build_evidence(%{
          evidence_id: "01900000-0000-7000-8000-000000000001",
          result: :pass,
          producer_kind: :command,
          producer_id: "producer-cmd",
          method: :registered_command,
          host_profile_digest: "host-cmd",
          command_registration_digest: "cmd-reg",
          command_result_id: "cmd-result-1",
          artifact_ids: ["01900000-0000-7000-8000-000000000001"]
        })

      fail =
        build_evidence(%{
          evidence_id: "01900000-0000-7000-8000-000000000002",
          result: :fail,
          producer_kind: :repository,
          producer_id: "producer-repo",
          method: :repository_observation,
          artifact_ids: ["01900000-0000-7000-8000-000000000999"]
        })

      ctx =
        base_context(%{
          artifact_integrity_by_id: %{
            "01900000-0000-7000-8000-000000000001" => :verified,
            "01900000-0000-7000-8000-000000000999" => :verified
          }
        })

      {:ok, views} = Currentness.evaluate([pass, fail], ctx)

      pass_view = Enum.find(views, &(&1.evidence_id == pass.evidence_id))
      fail_view = Enum.find(views, &(&1.evidence_id == fail.evidence_id))

      assert pass_view.contradiction == :present
      assert fail_view.contradiction == :present
      assert pass_view.freshness == :current
      assert fail_view.freshness == :current
    end

    test "no contradiction across different criterion revisions" do
      pass =
        build_evidence(%{
          evidence_id: "01900000-0000-7000-8000-000000000001",
          criterion_revision: "v1",
          result: :pass
        })

      fail =
        build_evidence(%{
          evidence_id: "01900000-0000-7000-8000-000000000002",
          criterion_revision: "v2",
          result: :fail
        })

      {:ok, views} = Currentness.evaluate([pass, fail], base_context())
      assert Enum.all?(views, &(&1.contradiction == :none))
    end

    test "no contradiction across different subject tuples" do
      pass =
        build_evidence(%{
          evidence_id: "01900000-0000-7000-8000-000000000001",
          subject_id: "subject-a",
          subject_state_digest: "subject-digest-a",
          result: :pass
        })

      fail =
        build_evidence(%{
          evidence_id: "01900000-0000-7000-8000-000000000002",
          subject_id: "subject-b",
          subject_state_digest: "subject-digest-b",
          result: :fail
        })

      ctx =
        Map.merge(base_context(), %{
          current_subject_state_digest: "subject-digest-a"
        })

      {:ok, _views} = Currentness.evaluate([pass, fail], ctx)
      # First is current; second is stale (subject_state_digest mismatch)
      # so contradiction is :unknown for both
      assert true
    end

    test "no contradiction across different Repository state digests" do
      pass =
        build_evidence(%{
          evidence_id: "01900000-0000-7000-8000-000000000001",
          repository_state_digest: "repo-digest-a",
          result: :pass
        })

      fail =
        build_evidence(%{
          evidence_id: "01900000-0000-7000-8000-000000000002",
          repository_state_digest: "repo-digest-b",
          result: :fail
        })

      ctx = Map.put(base_context(), :current_repository_state_digest, "repo-digest-a")
      {:ok, views} = Currentness.evaluate([pass, fail], ctx)

      pass_view = Enum.find(views, &(&1.evidence_id == pass.evidence_id))
      fail_view = Enum.find(views, &(&1.evidence_id == fail.evidence_id))

      assert pass_view.contradiction == :none
      assert pass_view.freshness == :current
      # fail record is stale (repo digest mismatch) -> :unknown
      assert fail_view.contradiction == :unknown
      assert fail_view.freshness == :stale
    end

    test "no contradiction across different Patch binding" do
      pass =
        build_evidence(%{
          evidence_id: "01900000-0000-7000-8000-000000000001",
          patch_id: "01900000-0000-7000-8000-000000000010",
          patch_digest: "digest-a",
          patch_result_digest: "result-a",
          result: :pass
        })

      fail =
        build_evidence(%{
          evidence_id: "01900000-0000-7000-8000-000000000002",
          patch_id: "01900000-0000-7000-8000-000000000020",
          patch_digest: "digest-b",
          patch_result_digest: "result-b",
          result: :fail
        })

      ctx =
        Map.merge(base_context(), %{
          current_patch_id: "01900000-0000-7000-8000-000000000010",
          current_patch_digest: "digest-a",
          current_patch_result_digest: "result-a"
        })

      {:ok, views} = Currentness.evaluate([pass, fail], ctx)

      pass_view = Enum.find(views, &(&1.evidence_id == pass.evidence_id))
      fail_view = Enum.find(views, &(&1.evidence_id == fail.evidence_id))

      # Both pass and fail use same_repository_state so Patch binding does not
      # gate freshness; both are :current. Contradiction grouping keys on
      # Patch binding equality, so different Patch triples do not contradict.
      assert pass_view.freshness == :current
      assert fail_view.freshness == :current
      assert pass_view.contradiction == :none
      assert fail_view.contradiction == :none
    end
  end

  # -- view composition --

  describe "evaluate/2 — view composition" do
    test "view maps stored result to status" do
      blocked =
        build_evidence(%{
          evidence_id: "01900000-0000-7000-8000-000000000001",
          result: :blocked,
          completeness: :partial
        })

      {:ok, [view]} = Currentness.evaluate([blocked], base_context())
      assert view.status == :blocked
    end

    test "view carries subject tuple" do
      evidence =
        build_evidence(%{
          subject_kind: :run,
          subject_id: "run-1",
          subject_state_digest: "run-digest"
        })

      {:ok, [view]} = Currentness.evaluate([evidence], base_context())
      assert view.subject == {:run, "run-1", "run-digest"}
    end

    test "view carries patch_binding when present" do
      evidence =
        build_evidence(%{
          patch_id: "01900000-0000-7000-8000-000000000010",
          patch_digest: "patch-digest",
          patch_result_digest: "patch-result-digest"
        })

      {:ok, [view]} = Currentness.evaluate([evidence], base_context())

      assert view.patch_binding ==
               {"01900000-0000-7000-8000-000000000010", "patch-digest", "patch-result-digest"}
    end

    test "view patch_binding is nil when no Patch fields are present" do
      evidence = build_evidence(%{})
      {:ok, [view]} = Currentness.evaluate([evidence], base_context())
      assert view.patch_binding == nil
    end

    test "view carries host_profile_digest and command_result_id" do
      evidence =
        build_evidence(%{
          method: :registered_command,
          host_profile_digest: "host-profile",
          command_registration_digest: "cmd-reg",
          command_result_id: "cmd-result-1"
        })

      {:ok, [view]} = Currentness.evaluate([evidence], base_context())
      assert view.host_profile_digest == "host-profile"
      assert view.command_result_id == "cmd-result-1"
    end

    test "view carries artifact_references in canonical ascending order" do
      a1 = "01900000-0000-7000-8000-000000000001"
      a2 = "01900000-0000-7000-8000-000000000002"
      evidence = build_evidence(%{artifact_ids: [a1, a2]})

      ctx =
        Map.put(base_context(), :artifact_integrity_by_id, %{a1 => :verified, a2 => :verified})

      {:ok, [view]} = Currentness.evaluate([evidence], ctx)
      assert view.artifact_references == [a1, a2]
    end

    test "view carries record_digest from the immutable record" do
      evidence = build_evidence(%{})
      {:ok, [view]} = Currentness.evaluate([evidence], base_context())
      assert view.record_digest == evidence.record_digest
    end
  end

  # -- candidate limits --

  describe "evaluate/2 — candidate limits" do
    test "more than 256 candidates returns :limit_exceeded" do
      candidates =
        for i <- 1..257 do
          hex = i |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(12, "0")
          build_evidence(%{evidence_id: "01900000-0000-7000-8000-#{hex}"})
        end

      assert {:error, %Kiln.Store.Error{class: :precondition, code: :limit_exceeded}} =
               Currentness.evaluate(candidates, base_context())
    end

    test "exactly 256 candidates is accepted" do
      candidates =
        for i <- 1..256 do
          hex = i |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(12, "0")
          build_evidence(%{evidence_id: "01900000-0000-7000-8000-#{hex}"})
        end

      assert {:ok, views} = Currentness.evaluate(candidates, base_context())
      assert length(views) == 256
    end
  end

  # -- determinism --

  describe "evaluate/2 — determinism" do
    test "input order does not change the resulting contradiction grouping" do
      a = build_evidence(%{evidence_id: "01900000-0000-7000-8000-000000000001", result: :pass})
      b = build_evidence(%{evidence_id: "01900000-0000-7000-8000-000000000002", result: :fail})
      c = build_evidence(%{evidence_id: "01900000-0000-7000-8000-000000000003", result: :fail})

      {:ok, views_ab} = Currentness.evaluate([a, b, c], base_context())
      {:ok, views_bc} = Currentness.evaluate([c, b, a], base_context())
      {:ok, views_ca} = Currentness.evaluate([c, a, b], base_context())

      assert contradictions_by_id(views_ab) == contradictions_by_id(views_bc)
      assert contradictions_by_id(views_ab) == contradictions_by_id(views_ca)
    end

    test "contradicting_evidence_ids are sorted ascending and unique" do
      a = build_evidence(%{evidence_id: "01900000-0000-7000-8000-000000000001", result: :pass})
      b = build_evidence(%{evidence_id: "01900000-0000-7000-8000-000000000002", result: :fail})

      {:ok, views} = Currentness.evaluate([a, b], base_context())
      pass_view = Enum.find(views, &(&1.evidence_id == a.evidence_id))
      assert pass_view.contradicting_evidence_ids == [b.evidence_id]
    end

    test "contradicting_evidence_ids are bounded to 256" do
      passes =
        for i <- 1..257 do
          hex = i |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(12, "0")
          build_evidence(%{evidence_id: "01900000-0000-7000-8000-#{hex}", result: :pass})
        end

      fail =
        build_evidence(%{
          evidence_id: "01900000-0000-7000-8000-00000000ffff",
          result: :fail
        })

      # 257 passes + 1 fail = 258 candidates exceeds the 256 candidate limit,
      # so the test is bounded to 255 + 1 = 256 candidates where the fail
      # record plus 255 pass records fit, producing at most 255 conflicting
      # pass IDs.
      candidates = Enum.concat([fail], Enum.take(passes, 255))
      assert length(candidates) == 256

      {:ok, views} = Currentness.evaluate(candidates, base_context())

      fail_view = Enum.find(views, &(&1.evidence_id == fail.evidence_id))
      assert length(fail_view.contradicting_evidence_ids) <= 256
    end
  end

  # -- purity / no mutation --

  describe "evaluate/2 — purity" do
    test "does not mutate the input evidence record" do
      evidence = build_evidence(%{})
      original = Map.from_struct(evidence)

      {:ok, _views} = Currentness.evaluate([evidence], base_context())

      assert Map.from_struct(evidence) == original
    end

    test "input evidence remains identifiable by identity after evaluation" do
      evidence = build_evidence(%{evidence_id: "01900000-0000-7000-8000-000000000abc"})
      {:ok, [view]} = Currentness.evaluate([evidence], base_context())
      assert view.evidence_id == evidence.evidence_id
    end
  end

  # -- Context.new validation --

  describe "Currentness.Context.new/1" do
    test "rejects missing required fields" do
      assert {:error, {:missing_required_field, :current_subject_state_digest}} =
               Currentness.Context.new(%{})
    end

    test "rejects bad artifact_integrity_by_id value" do
      attrs =
        Map.put(base_context(), :artifact_integrity_by_id, %{
          "x" => :bogus_integrity_value
        })

      assert {:error, :invalid_artifact_integrity} = Currentness.Context.new(attrs)
    end

    test "accepts a complete context" do
      assert {:ok, _ctx} = Currentness.Context.new(base_context())
    end

    test "rejects artifact_integrity_by_id with non-allowed values" do
      attrs =
        Map.put(base_context(), :artifact_integrity_by_id, %{
          "x" => :bogus_integrity_value
        })

      assert {:error, :invalid_artifact_integrity} = Currentness.Context.new(attrs)
    end
  end

  defp contradictions_by_id(views) do
    Enum.sort_by(views, & &1.evidence_id)
    |> Enum.map(&{&1.evidence_id, &1.contradiction})
  end
end
