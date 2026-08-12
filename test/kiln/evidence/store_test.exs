defmodule Kiln.Evidence.StoreTest do
  use ExUnit.Case, async: false

  alias Kiln.Artifact.PutRequest
  alias Kiln.Artifact.Store, as: ArtifactStore
  alias Kiln.Evidence.RecordRequest
  alias Kiln.Evidence.Store, as: EvidenceStore
  alias Kiln.Store

  @now "2026-08-10T12:00:00Z"
  @bytes "deterministic artifact bytes for evidence test"

  setup do
    base =
      Path.join(System.tmp_dir!(), "kiln-evidence-store-#{System.unique_integer([:positive])}")

    File.mkdir_p!(base)
    on_exit(fn -> File.rm_rf!(base) end)

    {:ready, store} =
      Store.start(
        path: Path.join(base, "state.sqlite3"),
        store_id: "evidence_store_test",
        now: @now
      )

    on_exit(fn -> stop(store.conn) end)

    {:ok, store: store, base: base}
  end

  defp stop(conn) do
    if Process.alive?(conn), do: GenServer.stop(conn)
    :ok
  catch
    :exit, _ -> :ok
  end

  defp publish_artifact(store, idempotency_key, artifact_id) do
    metadata = %{
      session_id: "session-1",
      run_id: "run-1",
      owner_kind: :session,
      owner_id: "session-1",
      producer_kind: :deterministic_service,
      producer_id: "producer-1",
      kind: :log,
      media_type: "text/plain",
      encoding: :utf_8,
      trust: :kiln_generated,
      sensitivity: :public,
      retention_class: :session,
      completeness: :complete
    }

    {:ok, request} =
      PutRequest.new(%{
        artifact_id: artifact_id,
        idempotency_key: idempotency_key,
        recorded_at: @now,
        bytes: @bytes,
        metadata: metadata
      })

    {:ok, _artifact, %{status: :committed}} = ArtifactStore.put(store, request)
    artifact_id
  end

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
        observed_at: @now,
        recorded_at: @now,
        idempotency_key: "idem-1"
      },
      overrides
    )
  end

  defp record_request(attrs \\ %{}, opts \\ []) do
    request = %{evidence: base_evidence_attrs(attrs)}

    request =
      case Keyword.get(opts, :admission_context) do
        nil -> request
        ctx -> Map.put(request, :admission_context, ctx)
      end

    request =
      case Keyword.get(opts, :warnings) do
        nil -> request
        warnings -> Map.put(request, :warnings, warnings)
      end

    RecordRequest.new(request)
  end

  # -- happy paths --

  describe "record/2 — happy paths" do
    test "commits a fresh Evidence record", %{store: store} do
      {:ok, request} = record_request()
      assert {:ok, evidence, %{status: :committed}} = EvidenceStore.record(store, request)
      assert evidence.evidence_id == request.evidence.evidence_id
      assert evidence.request_digest == request.evidence.request_digest
      assert evidence.record_digest == request.evidence.record_digest
    end

    test "returns :replayed for an exact idempotency retry", %{store: store} do
      {:ok, request} = record_request()
      assert {:ok, _committed, %{status: :committed}} = EvidenceStore.record(store, request)

      assert {:ok, replayed, %{status: :replayed}} = EvidenceStore.record(store, request)
      assert replayed.evidence_id == request.evidence.evidence_id
    end

    test "inserts evidence_artifacts associations", %{store: store} do
      a1 = publish_artifact(store, "artifact-key-1", "01900000-0000-7000-8000-000000000001")
      a2 = publish_artifact(store, "artifact-key-2", "01900000-0000-7000-8000-000000000002")

      {:ok, request} = record_request(%{artifact_ids: [a1, a2]})
      assert {:ok, evidence, %{status: :committed}} = EvidenceStore.record(store, request)
      assert evidence.artifact_ids == [a1, a2]

      {:ok, fetched, %{integrity_status: :verified}} =
        EvidenceStore.fetch(store, evidence.evidence_id)

      assert fetched.artifact_ids == [a1, a2]
    end

    test "inserts bounded warnings", %{store: store} do
      warnings = ["first warning", "second warning"]

      {:ok, request} =
        record_request(%{result: :blocked, completeness: :partial}, warnings: warnings)

      assert {:ok, _evidence, %{status: :committed}} = EvidenceStore.record(store, request)
    end
  end

  # -- idempotency --

  describe "record/2 — idempotency" do
    test "rejects conflicting reuse with a different request", %{store: store} do
      {:ok, request} = record_request()
      assert {:ok, _, %{status: :committed}} = EvidenceStore.record(store, request)

      {:ok, conflicting} =
        record_request(%{subject_state_digest: "different-subject-digest"})

      assert {:error, %Kiln.Store.Error{class: :idempotency_conflict}} =
               EvidenceStore.record(store, conflicting)
    end

    test "conflicting reuse writes no second row", %{store: store} do
      {:ok, request} = record_request()
      assert {:ok, _, %{status: :committed}} = EvidenceStore.record(store, request)

      {:ok, conflicting} =
        record_request(%{subject_state_digest: "different-subject-digest"})

      EvidenceStore.record(store, conflicting)

      rows =
        Kiln.Store.Connection.query!(
          store.conn,
          "SELECT COUNT(*) FROM evidence_records WHERE idempotency_key = ?1",
          [request.evidence.idempotency_key]
        )

      assert [[1]] == rows
    end
  end

  # -- integrity --

  describe "record/2 — integrity" do
    test "rejects an Evidence referencing a missing Artifact", %{store: store} do
      missing = "01900000-0000-7000-8000-000000000999"
      {:ok, request} = record_request(%{artifact_ids: [missing]})

      assert {:error, %Kiln.Store.Error{class: :integrity, code: :missing_artifact}} =
               EvidenceStore.record(store, request)
    end

    test "missing artifact writes no Evidence row", %{store: store} do
      missing = "01900000-0000-7000-8000-000000000999"
      {:ok, request} = record_request(%{artifact_ids: [missing]})

      EvidenceStore.record(store, request)

      rows =
        Kiln.Store.Connection.query!(
          store.conn,
          "SELECT COUNT(*) FROM evidence_records WHERE idempotency_key = ?1",
          [request.evidence.idempotency_key]
        )

      assert [[0]] == rows
    end
  end

  # -- admission_context --

  describe "record/2 — admission_context" do
    test "accepts matching admission_context", %{store: store} do
      ctx = %{
        current_subject_state_digest: "subject-digest",
        current_repository_state_digest: "repo-digest",
        current_evaluator_digest: "eval-digest"
      }

      {:ok, request} = record_request(%{}, admission_context: ctx)
      assert {:ok, _, %{status: :committed}} = EvidenceStore.record(store, request)
    end

    test "rejects mismatched admission_context as :stale", %{store: store} do
      ctx = %{
        current_subject_state_digest: "different-subject-digest",
        current_repository_state_digest: "repo-digest",
        current_evaluator_digest: "eval-digest"
      }

      {:ok, request} = record_request(%{}, admission_context: ctx)

      assert {:error, %Kiln.Store.Error{class: :integrity, code: :stale}} =
               EvidenceStore.record(store, request)
    end

    test "stale admission writes no Evidence row", %{store: store} do
      ctx = %{
        current_subject_state_digest: "different-subject-digest",
        current_repository_state_digest: "repo-digest",
        current_evaluator_digest: "eval-digest"
      }

      {:ok, request} = record_request(%{}, admission_context: ctx)
      EvidenceStore.record(store, request)

      rows =
        Kiln.Store.Connection.query!(
          store.conn,
          "SELECT COUNT(*) FROM evidence_records WHERE idempotency_key = ?1",
          [request.evidence.idempotency_key]
        )

      assert [[0]] == rows
    end
  end

  # -- fetch --

  describe "fetch/2" do
    test "returns the persisted immutable record", %{store: store} do
      {:ok, request} = record_request()
      assert {:ok, _, %{status: :committed}} = EvidenceStore.record(store, request)

      assert {:ok, fetched, %{integrity_status: :verified}} =
               EvidenceStore.fetch(store, request.evidence.evidence_id)

      assert fetched.evidence_id == request.evidence.evidence_id
      assert fetched.result == request.evidence.result
      assert fetched.subject_kind == request.evidence.subject_kind
      assert fetched.request_digest == request.evidence.request_digest
      assert fetched.record_digest == request.evidence.record_digest
    end

    test "returns unknown_evidence for missing evidence_id", %{store: store} do
      assert {:error, %Kiln.Store.Error{class: :precondition, code: :unknown_evidence}} =
               EvidenceStore.fetch(store, "01900000-0000-7000-8000-deadbeefcafe")
    end

    test "rehydrates evidence_artifacts in canonical position order", %{store: store} do
      a1 = publish_artifact(store, "art-key-a", "01900000-0000-7000-8000-00000000000a")
      a2 = publish_artifact(store, "art-key-b", "01900000-0000-7000-8000-00000000000b")
      a3 = publish_artifact(store, "art-key-c", "01900000-0000-7000-8000-00000000000c")

      {:ok, request} = record_request(%{artifact_ids: [a1, a2, a3]})
      {:ok, evidence, %{status: :committed}} = EvidenceStore.record(store, request)

      {:ok, fetched, %{integrity_status: :verified}} =
        EvidenceStore.fetch(store, evidence.evidence_id)

      assert fetched.artifact_ids == [a1, a2, a3]
    end
  end
end
