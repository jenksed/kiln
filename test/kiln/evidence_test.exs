defmodule Kiln.EvidenceTest do
  use ExUnit.Case, async: true

  alias Kiln.Evidence

  defp base_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        evidence_id: "01900000-0000-7000-8000-000000000000",
        session_id: "session-abc",
        run_id: "run-xyz",
        criterion_id: "criterion-1",
        criterion_revision: "v1",
        subject_id: "subject-1",
        subject_kind: :repository,
        subject_state_digest: "abcdef1234567890",
        producer_kind: :deterministic_service,
        producer_id: "producer-1",
        method: :repository_observation,
        result: :pass,
        repository_state_digest: "fedcba0987654321",
        artifact_ids: [],
        evaluator_digest: "evaldigest",
        observation_digest: "obsdigest",
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
    assert %Kiln.Store.Error{class: :precondition, code: ^code, message: message} = error
    assert is_binary(message) and message != ""
  end

  describe "new/1 — happy paths" do
    test "constructs a minimal blocked Evidence" do
      attrs = base_attrs(%{result: :blocked, completeness: :partial})
      assert {:ok, evidence} = Evidence.new(attrs)
      assert evidence.result == :blocked
      assert evidence.completeness == :partial
      assert evidence.schema == "kiln.evidence/v1"
      assert is_binary(evidence.request_digest)
      assert byte_size(evidence.request_digest) == 64
      assert is_binary(evidence.record_digest)
      assert byte_size(evidence.record_digest) == 64
    end

    test "constructs an unknown Evidence with missing completeness" do
      attrs = base_attrs(%{result: :unknown, completeness: :missing})
      assert {:ok, evidence} = Evidence.new(attrs)
      assert evidence.result == :unknown
      assert evidence.completeness == :missing
    end

    test "constructs Evidence with sorted UUIDv7 artifact_ids" do
      a = "01900000-0000-7000-8000-000000000001"
      b = "01900000-0000-7000-8000-000000000002"
      attrs = base_attrs(%{artifact_ids: [a, b]})
      assert {:ok, evidence} = Evidence.new(attrs)
      assert evidence.artifact_ids == [a, b]
    end

    test "preserves the recorded_at and observed_at text exactly" do
      attrs =
        base_attrs(%{observed_at: "2026-08-12T12:34:56Z", recorded_at: "2026-08-12T12:34:57Z"})

      assert {:ok, evidence} = Evidence.new(attrs)
      assert evidence.observed_at == "2026-08-12T12:34:56Z"
      assert evidence.recorded_at == "2026-08-12T12:34:57Z"
    end

    test "computes request_digest and record_digest from canonical map" do
      attrs1 = base_attrs(%{})
      attrs2 = base_attrs(%{})
      assert {:ok, e1} = Evidence.new(attrs1)
      assert {:ok, e2} = Evidence.new(attrs2)
      assert e1.request_digest == e2.request_digest
      assert e1.record_digest == e2.record_digest
    end

    test "different evidence_id yields same record_digest (record_digest excludes evidence_id)" do
      attrs2 = base_attrs(%{evidence_id: "01900000-0000-7000-8000-000000000999"})
      assert {:ok, e1} = Evidence.new(base_attrs())
      assert {:ok, e2} = Evidence.new(attrs2)
      assert e1.record_digest == e2.record_digest
    end
  end

  describe "new/1 — identifier and bound validation" do
    test "rejects empty session_id" do
      assert {:error, e} = Evidence.new(base_attrs(%{session_id: ""}))
      assert_precondition(e, :empty_identifier)
    end

    test "rejects session_id over 256 bytes" do
      assert {:error, e} = Evidence.new(base_attrs(%{session_id: String.duplicate("a", 257)}))
      assert_precondition(e, :limit_exceeded)
    end

    test "rejects criterion_revision over 64 bytes" do
      assert {:error, e} =
               Evidence.new(base_attrs(%{criterion_revision: String.duplicate("v", 65)}))

      assert_precondition(e, :limit_exceeded)
    end

    test "rejects recorded_at over 64 bytes" do
      assert {:error, e} =
               Evidence.new(base_attrs(%{recorded_at: String.duplicate("z", 65)}))

      assert_precondition(e, :limit_exceeded)
    end

    test "rejects rationale over 8192 bytes" do
      assert {:error, e} =
               Evidence.new(
                 base_attrs(%{
                   result: :blocked,
                   completeness: :partial,
                   rationale: String.duplicate("r", 8193)
                 })
               )

      assert_precondition(e, :limit_exceeded)
    end

    test "rejects identifier with NUL byte" do
      assert {:error, e} = Evidence.new(base_attrs(%{session_id: "abc\0def"}))
      assert_precondition(e, :disallowed_control_byte)
    end

    test "rejects identifier with disallowed control byte" do
      assert {:error, e} = Evidence.new(base_attrs(%{session_id: "abcdef"}))
      assert_precondition(e, :disallowed_control_byte)
    end
  end

  describe "new/1 — UUIDv7 enforcement" do
    test "rejects non-UUIDv7 evidence_id" do
      assert {:error, e} =
               Evidence.new(base_attrs(%{evidence_id: "01900000-0000-7000-8000-00000000000Z"}))

      assert_precondition(e, :malformed_uuid_v7)
    end

    test "rejects evidence_id with non-7 version nibble" do
      assert {:error, e} =
               Evidence.new(base_attrs(%{evidence_id: "01900000-0000-6000-8000-000000000000"}))

      assert_precondition(e, :malformed_uuid_v7)
    end

    test "rejects non-UUIDv7 inside artifact_ids" do
      bad = "01900000-0000-7000-8000-000000000001"
      attrs = base_attrs(%{artifact_ids: [bad, "not-a-uuid"]})
      assert {:error, e} = Evidence.new(attrs)
      assert_precondition(e, :malformed_uuid_v7)
    end
  end

  describe "new/1 — vocabulary enforcement" do
    test "rejects result outside pass/fail/blocked/unknown" do
      assert {:error, e} = Evidence.new(base_attrs(%{result: :bogus}))
      assert_precondition(e, :invalid_vocabulary)
    end

    test "rejects method outside the four accepted methods" do
      assert {:error, e} = Evidence.new(base_attrs(%{method: :oracle}))
      assert_precondition(e, :invalid_vocabulary)
    end

    test "rejects subject_kind outside the eight kinds" do
      assert {:error, e} = Evidence.new(base_attrs(%{subject_kind: :galaxy}))
      assert_precondition(e, :invalid_vocabulary)
    end

    test "rejects freshness_rule outside the four state-based rules" do
      assert {:error, e} = Evidence.new(base_attrs(%{freshness_rule: :time_bound}))
      assert_precondition(e, :invalid_vocabulary)
    end

    test "rejects time_bound in any spelling" do
      for rule <- [:time_bound, :ttl_seconds, :freshness_ttl] do
        assert {:error, _} = Evidence.new(base_attrs(%{freshness_rule: rule}))
      end
    end

    test "rejects completeness outside the five-value vocabulary" do
      assert {:error, e} = Evidence.new(base_attrs(%{completeness: :questionable}))
      assert_precondition(e, :invalid_vocabulary)
    end
  end

  describe "new/1 — cross-field safety" do
    test "rejects pass with non-complete completeness" do
      assert {:error, e} = Evidence.new(base_attrs(%{result: :pass, completeness: :partial}))
      assert_precondition(e, :incomplete_proof)
    end

    test "rejects fail with non-complete completeness" do
      assert {:error, e} = Evidence.new(base_attrs(%{result: :fail, completeness: :truncated}))
      assert_precondition(e, :incomplete_proof)
    end

    test "accepts blocked with partial completeness" do
      assert {:ok, _} = Evidence.new(base_attrs(%{result: :blocked, completeness: :partial}))
    end

    test "accepts unknown with missing completeness" do
      assert {:ok, _} = Evidence.new(base_attrs(%{result: :unknown, completeness: :missing}))
    end

    test "rejects patch_id without patch_digest" do
      attrs =
        base_attrs(%{
          patch_id: "01900000-0000-7000-8000-000000000010",
          patch_digest: nil,
          patch_result_digest: "result-digest"
        })

      assert {:error, e} = Evidence.new(attrs)
      assert_precondition(e, :inconsistent_patch_binding)
    end

    test "rejects patch_digest with patch_result_digest nil" do
      attrs =
        base_attrs(%{
          patch_id: "01900000-0000-7000-8000-000000000010",
          patch_digest: "patch-digest",
          patch_result_digest: nil
        })

      assert {:error, e} = Evidence.new(attrs)
      assert_precondition(e, :inconsistent_patch_binding)
    end

    test "accepts all patch fields nil" do
      assert {:ok, _} =
               Evidence.new(
                 base_attrs(%{
                   patch_id: nil,
                   patch_digest: nil,
                   patch_result_digest: nil
                 })
               )
    end

    test "accepts all patch fields present" do
      assert {:ok, _} =
               Evidence.new(
                 base_attrs(%{
                   patch_id: "01900000-0000-7000-8000-000000000010",
                   patch_digest: "patch-digest",
                   patch_result_digest: "patch-result-digest"
                 })
               )
    end

    test "rejects registered_command without command_result_id" do
      attrs =
        base_attrs(%{
          method: :registered_command,
          host_profile_digest: "host-profile",
          command_registration_digest: "command-reg",
          command_result_id: nil
        })

      assert {:error, e} = Evidence.new(attrs)
      assert_precondition(e, :missing_command_binding)
    end

    test "rejects registered_command without host_profile_digest" do
      attrs =
        base_attrs(%{
          method: :registered_command,
          host_profile_digest: nil,
          command_registration_digest: "command-reg",
          command_result_id: "cmd-result-1"
        })

      assert {:error, e} = Evidence.new(attrs)
      assert_precondition(e, :missing_command_binding)
    end

    test "accepts registered_command with all required bindings" do
      attrs =
        base_attrs(%{
          method: :registered_command,
          host_profile_digest: "host-profile",
          command_registration_digest: "command-reg",
          command_result_id: "cmd-result-1"
        })

      assert {:ok, _} = Evidence.new(attrs)
    end

    test "accepts repository_observation with all command fields nil" do
      assert {:ok, _} =
               Evidence.new(
                 base_attrs(%{
                   method: :repository_observation,
                   host_profile_digest: nil,
                   command_registration_digest: nil,
                   command_result_id: nil
                 })
               )
    end
  end

  describe "new/1 — artifact_ids validation" do
    test "rejects more than 32 artifact_ids" do
      ids =
        for i <- 1..33 do
          i_hex = i |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(12, "0")
          "01900000-0000-7000-8000-#{i_hex}"
        end

      attrs = base_attrs(%{artifact_ids: ids})
      assert {:error, e} = Evidence.new(attrs)
      assert_precondition(e, :limit_exceeded)
    end

    test "rejects unsorted artifact_ids" do
      a = "01900000-0000-7000-8000-000000000002"
      b = "01900000-0000-7000-8000-000000000001"
      attrs = base_attrs(%{artifact_ids: [a, b]})
      assert {:error, e} = Evidence.new(attrs)
      assert_precondition(e, :unsorted_artifact_ids)
    end

    test "rejects duplicate artifact_ids" do
      a = "01900000-0000-7000-8000-000000000001"
      attrs = base_attrs(%{artifact_ids: [a, a]})
      assert {:error, e} = Evidence.new(attrs)
      assert_precondition(e, :duplicate_artifact_id)
    end

    test "accepts empty artifact_ids" do
      assert {:ok, _} = Evidence.new(base_attrs(%{artifact_ids: []}))
    end

    test "accepts 32 sorted unique artifact_ids" do
      ids =
        for i <- 1..32 do
          i_hex = i |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(12, "0")
          "01900000-0000-7000-8000-#{i_hex}"
        end

      attrs = base_attrs(%{artifact_ids: ids})
      assert {:ok, evidence} = Evidence.new(attrs)
      assert length(evidence.artifact_ids) == 32
    end
  end

  describe "new/1 — required field enforcement" do
    test "rejects missing evidence_id" do
      attrs = Map.delete(base_attrs(), :evidence_id)
      assert {:error, e} = Evidence.new(attrs)
      assert_precondition(e, :missing_field)
    end

    test "rejects missing artifact_ids" do
      attrs = Map.delete(base_attrs(), :artifact_ids)
      assert {:error, e} = Evidence.new(attrs)
      assert_precondition(e, :missing_field)
    end

    test "rejects missing idempotency_key" do
      attrs = Map.delete(base_attrs(), :idempotency_key)
      assert {:error, e} = Evidence.new(attrs)
      assert_precondition(e, :missing_field)
    end
  end

  describe "new/1 — digest shape" do
    test "request_digest and record_digest are distinct 64-char lowercase hex" do
      assert {:ok, evidence} = Evidence.new(base_attrs())
      assert byte_size(evidence.request_digest) == 64
      assert byte_size(evidence.record_digest) == 64
      assert Regex.match?(~r/^[0-9a-f]{64}$/, evidence.request_digest)
      assert Regex.match?(~r/^[0-9a-f]{64}$/, evidence.record_digest)
      assert evidence.request_digest != evidence.record_digest
    end

    test "changing idempotency_key changes only request_digest (record_digest excludes idempotency_key)" do
      assert {:ok, a} = Evidence.new(base_attrs(%{idempotency_key: "idem-a"}))
      assert {:ok, b} = Evidence.new(base_attrs(%{idempotency_key: "idem-b"}))
      assert a.request_digest != b.request_digest
      assert a.record_digest == b.record_digest
    end

    test "changing artifact_ids changes both digests" do
      x = "01900000-0000-7000-8000-000000000001"
      assert {:ok, a} = Evidence.new(base_attrs(%{artifact_ids: []}))
      assert {:ok, b} = Evidence.new(base_attrs(%{artifact_ids: [x]}))
      assert a.record_digest != b.record_digest
    end
  end

  describe "schema accessors" do
    test "schema/0 returns kiln.evidence/v1" do
      assert Evidence.schema() == "kiln.evidence/v1"
    end

    test "schema?/1 is true only for the canonical identifier" do
      assert Evidence.schema?("kiln.evidence/v1")
      refute Evidence.schema?("kiln.evidence/v2")
      refute Evidence.schema?(nil)
    end

    test "exposes the documented byte and count bounds" do
      assert Evidence.max_artifact_ids() == 32
      assert Evidence.max_warnings() == 64
      assert Evidence.max_warning_bytes() == 1024
      assert Evidence.max_aggregate_warning_bytes() == 16_384
      assert Evidence.max_rationale_bytes() == 8192
    end
  end
end
