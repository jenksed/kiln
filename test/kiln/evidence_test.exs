defmodule Kiln.EvidenceTest do
  use ExUnit.Case, async: true

  alias Kiln.Evidence
  alias Kiln.Evidence.{Completeness, Freshness}
  alias Kiln.Store.Error

  @base %{
    subject_id: "ses_00000000000000000000000000000001",
    subject_kind: :session,
    subject_state_digest: "sha256:" <> String.duplicate("a", 64),
    producer_kind: :internal,
    producer_id: "kiln-test",
    method: :observed,
    freshness_class: :durable,
    freshness_ttl_seconds: nil,
    completeness_class: :complete,
    observed_at: "2026-08-08T01:23:45Z",
    recorded_at: "2026-08-08T01:23:46Z",
    artifact_id: nil
  }

  describe "canonical digest and bounded vocabulary (P1-S02-T01-AC04)" do
    test "two constructions with identical values produce identical evidence_id" do
      assert {:ok, a} = Evidence.new(@base)
      assert {:ok, b} = Evidence.new(@base)

      assert a.evidence_id == b.evidence_id
      assert byte_size(a.evidence_id) == 7 + 64
      assert a.evidence_id =~ ~r/^sha256:[0-9a-f]{64}$/
    end

    test "a single changed byte in any field changes the evidence_id" do
      assert {:ok, a} = Evidence.new(@base)

      assert {:ok, b} =
               Evidence.new(%{@base | recorded_at: "2026-08-08T01:23:47Z"})

      refute a.evidence_id == b.evidence_id
    end

    test "freshness_class atoms are accepted and the TTL constraint is enforced" do
      for freshness_class <- Freshness.classes() do
        ttl =
          case freshness_class do
            :durable -> nil
            _ -> 60
          end

        assert {:ok, ev} =
                 Evidence.new(%{
                   @base
                   | freshness_class: freshness_class,
                     freshness_ttl_seconds: ttl
                 })

        assert ev.freshness_class == freshness_class
      end
    end

    test "completeness_class atoms are accepted" do
      for completeness_class <- Completeness.classes() do
        assert {:ok, ev} = Evidence.new(%{@base | completeness_class: completeness_class})
        assert ev.completeness_class == completeness_class
      end
    end

    test "subject_kind and producer_kind and method atoms are accepted" do
      for subject_kind <- Evidence.subject_kinds(),
          producer_kind <- Evidence.producer_kinds(),
          method <- Evidence.methods() do
        assert {:ok, ev} =
                 Evidence.new(%{
                   @base
                   | subject_kind: subject_kind,
                     producer_kind: producer_kind,
                     method: method
                 })

        assert ev.subject_kind == subject_kind
        assert ev.producer_kind == producer_kind
        assert ev.method == method
      end
    end
  end

  describe "bounded vocabulary rejection (P1-S02-T01-AC04)" do
    test "an unknown subject_kind is rejected" do
      assert {:error, %Error{class: :evidence, details: %{field: :subject_kind}}} =
               Evidence.new(%{@base | subject_kind: :bogus})
    end

    test "an unknown producer_kind is rejected" do
      assert {:error, %Error{class: :evidence, details: %{field: :producer_kind}}} =
               Evidence.new(%{@base | producer_kind: :oracle})
    end

    test "an unknown method is rejected" do
      assert {:error, %Error{class: :evidence, details: %{field: :method}}} =
               Evidence.new(%{@base | method: :guessed})
    end

    test "an unknown freshness_class is rejected" do
      assert {:error, %Error{class: :evidence, details: %{field: :freshness_class}}} =
               Evidence.new(%{@base | freshness_class: :forever})
    end

    test "an unknown completeness_class is rejected" do
      assert {:error, %Error{class: :evidence, details: %{field: :completeness_class}}} =
               Evidence.new(%{@base | completeness_class: :partialish})
    end

    test "an empty subject_id is rejected" do
      assert {:error, %Error{class: :evidence, details: %{field: :subject_id}}} =
               Evidence.new(%{@base | subject_id: ""})
    end

    test "a malformed subject_state_digest is rejected" do
      assert {:error, %Error{class: :evidence, details: %{field: :subject_state_digest}}} =
               Evidence.new(%{@base | subject_state_digest: "sha256:not-hex"})
    end
  end

  describe "freshness TTL constraint (P1-S02-T01-AC04)" do
    test "a :transient row with nil TTL is rejected" do
      assert {:error, %Error{class: :evidence, details: %{field: :freshness_ttl_seconds}}} =
               Evidence.new(%{@base | freshness_class: :transient, freshness_ttl_seconds: nil})
    end

    test "a :transient row with negative TTL is rejected" do
      assert {:error, %Error{class: :evidence, details: %{field: :freshness_ttl_seconds}}} =
               Evidence.new(%{@base | freshness_class: :transient, freshness_ttl_seconds: -1})
    end

    test "a :durable row with non-nil TTL is rejected" do
      assert {:error, %Error{class: :evidence, details: %{field: :freshness_ttl_seconds}}} =
               Evidence.new(%{@base | freshness_class: :durable, freshness_ttl_seconds: 60})
    end

    test "a :stable row with nil TTL is rejected" do
      assert {:error, %Error{class: :evidence, details: %{field: :freshness_ttl_seconds}}} =
               Evidence.new(%{@base | freshness_class: :stable, freshness_ttl_seconds: nil})
    end
  end

  describe "optional artifact_id validation (P1-S02-T01-AC04)" do
    test "a malformed artifact_id is rejected" do
      assert {:error, %Error{class: :evidence, details: %{field: :artifact_id}}} =
               Evidence.new(%{@base | artifact_id: "sha256:not-hex"})
    end

    test "a well-formed artifact_id is accepted" do
      assert {:ok, ev} =
               Evidence.new(%{@base | artifact_id: "sha256:" <> String.duplicate("b", 64)})

      assert ev.artifact_id == "sha256:" <> String.duplicate("b", 64)
    end

    test "nil artifact_id is accepted" do
      assert {:ok, ev} = Evidence.new(%{@base | artifact_id: nil})
      assert ev.artifact_id == nil
    end
  end

  describe "protected failure matrix (P1-S02-T01-AC05 / R06)" do
    test "replay_attack: two Evidence rows with identical struct values produce identical evidence_id" do
      {:ok, a} = Evidence.new(@base)
      {:ok, b} = Evidence.new(@base)

      assert a.evidence_id == b.evidence_id

      {:ok, c} = Evidence.new(%{@base | producer_id: "different-producer"})
      refute a.evidence_id == c.evidence_id
    end

    test "contradiction: two Evidence rows with the same subject_id and producer_kind but conflicting method have distinct evidence_ids" do
      {:ok, observed} = Evidence.new(%{@base | method: :observed})
      {:ok, derived} = Evidence.new(%{@base | method: :derived})

      assert observed.evidence_id != derived.evidence_id
      assert observed.subject_id == derived.subject_id
      assert observed.producer_kind == derived.producer_kind
    end

    test "freshness_expired: a :transient row with a finite TTL carries the TTL on the struct so downstream freshness checks can read it" do
      assert {:ok, ev} =
               Evidence.new(%{
                 @base
                 | freshness_class: :transient,
                   freshness_ttl_seconds: 60
               })

      assert ev.freshness_class == :transient
      assert ev.freshness_ttl_seconds == 60
    end

    test "incomplete: a row with completeness_class :incomplete is accepted but the bounded vocabulary guarantees the producer must declare it" do
      assert {:ok, ev} = Evidence.new(%{@base | completeness_class: :incomplete})
      assert ev.completeness_class == :incomplete
    end

    test "stale_state_binding: the typed Evidence carries subject_state_digest explicitly so downstream protection can reject mismatches" do
      assert {:ok, ev} = Evidence.new(@base)
      assert ev.subject_state_digest =~ ~r/^sha256:[0-9a-f]{64}$/

      assert {:error, %Error{class: :evidence, details: %{field: :subject_state_digest}}} =
               Evidence.new(%{@base | subject_state_digest: "sha256:not-hex"})
    end
  end
end
