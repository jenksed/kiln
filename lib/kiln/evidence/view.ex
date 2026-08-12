defmodule Kiln.Evidence.View do
  @moduledoc """
  The canonical first-month Evidence view.

  An `EvidenceView` is the pure composition of an immutable `Evidence`
  record plus a currentness result. It is the artifact emitted by
  `Kiln.Evidence.Currentness.evaluate/2` and consumed by the active
  first-month conformance projection.

  The view is ephemeral. It never writes back to the persisted `Evidence`,
  never promotes or rewrites the stored result, and never changes the
  immutable record. Stored `result` is mapped to `status` for projection
  only (P1-S02-T01-R07, R15).

  ## Fields

    * `status` — the persisted Evidence `result` (`pass | fail | blocked |
      unknown`).
    * `subject` — the canonical subject tuple `{subject_kind, subject_id,
      subject_state_digest}`.
    * `repository_state_digest` — the stored Repository state.
    * `patch_binding` — the canonical nullable Patch triple
      `{patch_id, patch_digest, patch_result_digest}` or `nil` when the
      Evidence carries no Patch binding.
    * `host_profile_digest` — the stored nullable host/environment
      fingerprint.
    * `command_result_id` — the stored nullable Command result id.
    * `artifact_references` — the canonical plural Artifact set, in
      ascending sorted order.
    * `freshness` — `:current | :stale | :unknown`.
    * `contradiction` — `:none | :present | :unknown`.
    * `invalidated_at` — caller-supplied explicit invalidation timestamp
      or `nil`.
    * `contradicting_evidence_ids` — bounded list of contradicting
      Evidence IDs (at most 256).

  The active conformance projection emits the subset
  `kind`, `evidence_id`, `criterion_id`, `status`, `freshness`,
  `completeness`, `contradiction`, `repository_state_digest`, and
  `record_digest` from this view.
  """

  @type freshness :: :current | :stale | :unknown
  @type contradiction :: :none | :present | :unknown

  @type t :: %__MODULE__{
          evidence_id: String.t(),
          criterion_id: String.t(),
          subject: {Kiln.Evidence.subject_kind(), String.t(), String.t()},
          repository_state_digest: String.t(),
          patch_binding: {String.t() | nil, String.t() | nil, String.t() | nil} | nil,
          host_profile_digest: String.t() | nil,
          command_result_id: String.t() | nil,
          artifact_references: [String.t()],
          status: Kiln.Evidence.result(),
          completeness: Kiln.Evidence.completeness(),
          freshness: freshness(),
          contradiction: contradiction(),
          invalidated_at: String.t() | nil,
          record_digest: String.t(),
          contradicting_evidence_ids: [String.t()]
        }

  @enforce_keys [
    :evidence_id,
    :criterion_id,
    :subject,
    :repository_state_digest,
    :patch_binding,
    :host_profile_digest,
    :command_result_id,
    :artifact_references,
    :status,
    :completeness,
    :freshness,
    :contradiction,
    :invalidated_at,
    :record_digest,
    :contradicting_evidence_ids
  ]

  defstruct [
    :evidence_id,
    :criterion_id,
    :subject,
    :repository_state_digest,
    :patch_binding,
    :host_profile_digest,
    :command_result_id,
    :artifact_references,
    :status,
    :completeness,
    :freshness,
    :contradiction,
    :invalidated_at,
    :record_digest,
    :contradicting_evidence_ids
  ]

  @doc """
  Build a canonical EvidenceView from an Evidence record plus a pure
  currentness result. Pure, total, and never reads or writes the Store.
  """
  @spec from_evidence(Kiln.Evidence.t(), keyword()) :: t()
  def from_evidence(%Kiln.Evidence{} = evidence, opts) do
    freshness = Keyword.fetch!(opts, :freshness)
    contradiction = Keyword.fetch!(opts, :contradiction)
    invalidated_at = Keyword.fetch!(opts, :invalidated_at)
    contradicting_evidence_ids = Keyword.get(opts, :contradicting_evidence_ids, [])

    %__MODULE__{
      evidence_id: evidence.evidence_id,
      criterion_id: evidence.criterion_id,
      subject: {evidence.subject_kind, evidence.subject_id, evidence.subject_state_digest},
      repository_state_digest: evidence.repository_state_digest,
      patch_binding: patch_binding(evidence),
      host_profile_digest: evidence.host_profile_digest,
      command_result_id: evidence.command_result_id,
      artifact_references: evidence.artifact_ids,
      status: evidence.result,
      completeness: evidence.completeness,
      freshness: freshness,
      contradiction: contradiction,
      invalidated_at: invalidated_at,
      record_digest: evidence.record_digest,
      contradicting_evidence_ids: contradicting_evidence_ids
    }
  end

  defp patch_binding(%Kiln.Evidence{
         patch_id: nil,
         patch_digest: nil,
         patch_result_digest: nil
       }),
       do: nil

  defp patch_binding(%Kiln.Evidence{
         patch_id: id,
         patch_digest: digest,
         patch_result_digest: rd
       }),
       do: {id, digest, rd}

  @doc """
  Project a first-month conformance evidence map.

  Emits exactly the subset defined by `docs/contracts/kiln-first-month.schema.json`:
  `kind`, `evidence_id`, `criterion_id`, `status`, `freshness`,
  `completeness`, `contradiction`, `repository_state_digest`, and
  `record_digest`. The stored `result` is mapped to `status`; every other
  field is read directly. The projection is pure and cannot mutate the
  stored record or promote its result (P1-S02-T01-R07, AC05).
  """
  @spec to_first_month(t()) :: %{
          required(:kind) => :evidence,
          required(:evidence_id) => String.t(),
          required(:criterion_id) => String.t(),
          required(:status) => Kiln.Evidence.result(),
          required(:freshness) => freshness(),
          required(:completeness) => Kiln.Evidence.completeness(),
          required(:contradiction) => contradiction(),
          required(:repository_state_digest) => String.t(),
          required(:record_digest) => String.t()
        }
  def to_first_month(%__MODULE__{} = view) do
    %{
      kind: :evidence,
      evidence_id: view.evidence_id,
      criterion_id: view.criterion_id,
      status: view.status,
      freshness: view.freshness,
      completeness: view.completeness,
      contradiction: view.contradiction,
      repository_state_digest: view.repository_state_digest,
      record_digest: view.record_digest
    }
  end
end
