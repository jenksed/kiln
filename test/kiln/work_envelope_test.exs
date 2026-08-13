defmodule Kiln.WorkEnvelopeTest do
  use ExUnit.Case, async: true

  alias Kiln.Store.Error
  alias Kiln.WorkEnvelope

  @fixture %{
    "schema" => "engineering-system/work-envelope/v0",
    "work_id" => "wfg-repository-recon-001",
    "created_at" => "2026-08-13T00:00:00Z",
    "producer" => %{
      "product" => "loadout",
      "version" => "1.0.0"
    },
    "goal" => %{
      "title" => "Understand this repository",
      "success_conditions" => ["report architecture anchors", "report observed constraints"]
    },
    "capability" => %{
      "id" => "repository-recon",
      "contract_version" => "0.1.0",
      "method_provenance" => [
        %{"id" => "loadout/recon-fixture", "version" => "0.0.1"}
      ]
    },
    "project_state" => %{
      "repository" => "/path/to/repository",
      "base_commit" => "0123456789abcdef0123456789abcdef01234567",
      "workspace_state_digest" => "sha256:abc"
    },
    "scope" => %{
      "included" => ["tracked repository files"],
      "excluded" => ["mutation"]
    },
    "constraints" => %{
      "must" => ["distinguish observations from inferences"],
      "must_not" => ["modify repository state"]
    },
    "proof_obligations" => [
      %{
        "id" => "repo-state-observed",
        "kind" => "evidence",
        "requirement" => "report the exact commit inspected"
      }
    ],
    "authority_requests" => [
      %{"capability" => "git.read", "scope" => "/path/to/repository"}
    ]
  }

  describe "new/1" do
    test "accepts a valid Work Envelope and produces an envelope struct" do
      assert {:ok, envelope} = WorkEnvelope.new(@fixture)
      assert envelope.work_id == "wfg-repository-recon-001"
      assert envelope.producer.product == "loadout"
      assert envelope.capability.id == "repository-recon"
      assert WorkEnvelope.accepted_capability_id() == "repository-recon"
    end

    test "rejects an unknown schema identifier" do
      attrs = Map.put(@fixture, "schema", "engineering-system/work-envelope/v9")
      assert {:error, %Error{code: :unsupported_schema}} = WorkEnvelope.new(attrs)
    end

    test "rejects an unsupported capability id" do
      attrs =
        @fixture
        |> put_in(["capability", "id"], "deploy-cluster")

      assert {:error, %Error{code: :unsupported_capability}} = WorkEnvelope.new(attrs)
    end

    test "rejects an unsupported producer product" do
      attrs = put_in(@fixture, ["producer", "product"], "kiln-cli")
      assert {:error, %Error{code: :unsupported_producer}} = WorkEnvelope.new(attrs)
    end

    test "rejects an empty work_id" do
      attrs = Map.put(@fixture, "work_id", "")
      assert {:error, %Error{code: :empty_text}} = WorkEnvelope.new(attrs)
    end

    test "rejects a missing goal" do
      attrs = Map.delete(@fixture, "goal")
      assert {:error, %Error{code: :missing_field}} = WorkEnvelope.new(attrs)
    end

    test "rejects an empty success_conditions list" do
      attrs = put_in(@fixture, ["goal", "success_conditions"], [])
      assert {:error, %Error{code: :missing_goal_conditions}} = WorkEnvelope.new(attrs)
    end

    test "rejects an invalid base_commit shape" do
      attrs = put_in(@fixture, ["project_state", "base_commit"], "not-a-sha")
      assert {:error, %Error{code: :invalid_base_commit}} = WorkEnvelope.new(attrs)
    end

    test "rejects an authority_request with empty capability" do
      attrs = put_in(@fixture, ["authority_requests", Access.at(0), "capability"], "")
      assert {:error, %Error{code: :empty_text}} = WorkEnvelope.new(attrs)
    end

    test "rejects a malformed proof_obligation" do
      attrs = put_in(@fixture, ["proof_obligations"], [%{"id" => "x"}])
      assert {:error, %Error{code: :invalid_proof_obligation}} = WorkEnvelope.new(attrs)
    end

    test "rejects a context_refs list with non-string entries" do
      attrs = Map.put(@fixture, "context_refs", [123])
      assert {:error, %Error{code: :invalid_context_ref}} = WorkEnvelope.new(attrs)
    end
  end

  describe "request_digest/1" do
    test "produces a stable digest for identical semantically-bound fields" do
      {:ok, envelope_a} = WorkEnvelope.new(@fixture)
      {:ok, envelope_b} = WorkEnvelope.new(@fixture)
      assert WorkEnvelope.request_digest(envelope_a) == WorkEnvelope.request_digest(envelope_b)
    end

    test "produces different digests when the goal changes" do
      {:ok, envelope_a} = WorkEnvelope.new(@fixture)

      different_goal = put_in(@fixture, ["goal", "title"], "Different goal")
      {:ok, envelope_b} = WorkEnvelope.new(different_goal)

      assert WorkEnvelope.request_digest(envelope_a) != WorkEnvelope.request_digest(envelope_b)
    end

    test "produces different digests when the capability id changes" do
      {:ok, envelope_a} = WorkEnvelope.new(@fixture)

      different_capability = put_in(@fixture, ["capability", "contract_version"], "9.9.9")
      {:ok, envelope_b} = WorkEnvelope.new(different_capability)

      assert WorkEnvelope.request_digest(envelope_a) != WorkEnvelope.request_digest(envelope_b)
    end
  end

  describe "requested_capabilities/1" do
    test "returns the unique sorted capability strings" do
      {:ok, envelope} = WorkEnvelope.new(@fixture)

      assert WorkEnvelope.requested_capabilities(envelope) == ["git.read"]
    end

    test "deduplicates and sorts repeated capabilities" do
      attrs =
        @fixture
        |> put_in(
          ["authority_requests"],
          [
            %{"capability" => "git.read", "scope" => "/path/to/repository"},
            %{"capability" => "git.read", "scope" => "/path/to/other"},
            %{"capability" => "git.read", "scope" => "/path/to/repository"}
          ]
        )

      {:ok, envelope} = WorkEnvelope.new(attrs)

      assert WorkEnvelope.requested_capabilities(envelope) == ["git.read"]
    end
  end
end
