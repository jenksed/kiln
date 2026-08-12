defmodule Kiln.Evidence.Currentness.Context do
  @moduledoc """
  The typed currentness Context accepted by `Kiln.Evidence.Currentness.evaluate/2`.

  The Context carries the explicit current bindings and integrity observations
  the caller proves at evaluation time. Every field except
  `artifact_integrity_by_id`, `invalidated_at`, and `evaluated_at` is required;
  nil is only accepted where the plan explicitly says the binding may be null.

  The Context performs no Store, filesystem, clock, or process access.
  """

  alias Kiln.Evidence

  @enforce_keys [
    :current_subject_state_digest,
    :current_repository_state_digest,
    :current_evaluator_digest,
    :artifact_integrity_by_id,
    :invalidated_at,
    :evaluated_at
  ]

  defstruct [
    :current_subject_state_digest,
    :current_repository_state_digest,
    :current_patch_id,
    :current_patch_digest,
    :current_patch_result_digest,
    :current_host_profile_digest,
    :current_command_registration_digest,
    :current_command_result_id,
    :current_evaluator_digest,
    artifact_integrity_by_id: %{},
    invalidated_at: nil,
    evaluated_at: nil
  ]

  @type artifact_integrity :: :verified | :corrupt | :missing | :unknown

  @type t :: %__MODULE__{
          current_subject_state_digest: String.t(),
          current_repository_state_digest: String.t(),
          current_patch_id: String.t() | nil,
          current_patch_digest: String.t() | nil,
          current_patch_result_digest: String.t() | nil,
          current_host_profile_digest: String.t() | nil,
          current_command_registration_digest: String.t() | nil,
          current_command_result_id: String.t() | nil,
          current_evaluator_digest: String.t(),
          artifact_integrity_by_id: %{optional(String.t()) => artifact_integrity()},
          invalidated_at: String.t() | nil,
          evaluated_at: String.t() | nil
        }

  @doc """
  Build a Context from the given map, validating required keys and
  optional-key types.

  Required keys:

    * `current_subject_state_digest`
    * `current_repository_state_digest`
    * `current_evaluator_digest`
    * `evaluated_at`

  Optional keys default to `nil`; their presence must match one of the
  accepted plan types.
  """
  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_map(attrs) do
    required =
      ~w(current_subject_state_digest current_repository_state_digest current_evaluator_digest evaluated_at)a

    case Enum.find(required, fn key -> not Map.has_key?(attrs, key) end) do
      nil ->
        build(attrs)

      key ->
        {:error, {:missing_required_field, key}}
    end
  end

  defp build(attrs) do
    artifact_integrity = Map.get(attrs, :artifact_integrity_by_id, %{})

    with :ok <- validate_integrity_map(artifact_integrity),
         :ok <- validate_optional_string(:current_patch_id, attrs),
         :ok <- validate_optional_string(:current_patch_digest, attrs),
         :ok <- validate_optional_string(:current_patch_result_digest, attrs),
         :ok <- validate_optional_string(:current_host_profile_digest, attrs),
         :ok <- validate_optional_string(:current_command_registration_digest, attrs),
         :ok <- validate_optional_string(:current_command_result_id, attrs),
         :ok <- validate_optional_string(:invalidated_at, attrs) do
      {:ok,
       %__MODULE__{
         current_subject_state_digest: Map.fetch!(attrs, :current_subject_state_digest),
         current_repository_state_digest: Map.fetch!(attrs, :current_repository_state_digest),
         current_patch_id: Map.get(attrs, :current_patch_id),
         current_patch_digest: Map.get(attrs, :current_patch_digest),
         current_patch_result_digest: Map.get(attrs, :current_patch_result_digest),
         current_host_profile_digest: Map.get(attrs, :current_host_profile_digest),
         current_command_registration_digest:
           Map.get(attrs, :current_command_registration_digest),
         current_command_result_id: Map.get(attrs, :current_command_result_id),
         current_evaluator_digest: Map.fetch!(attrs, :current_evaluator_digest),
         artifact_integrity_by_id: artifact_integrity,
         invalidated_at: Map.get(attrs, :invalidated_at),
         evaluated_at: Map.fetch!(attrs, :evaluated_at)
       }}
    end
  end

  defp validate_integrity_map(value) when is_map(value) do
    cond do
      not Enum.all?(value, fn {_, v} ->
        v in [:verified, :corrupt, :missing, :unknown]
      end) ->
        {:error, :invalid_artifact_integrity}

      true ->
        :ok
    end
  end

  defp validate_integrity_map(_), do: {:error, :invalid_artifact_integrity}

  defp validate_optional_string(_key, _attrs), do: :ok
end

defmodule Kiln.Evidence.Currentness do
  @moduledoc """
  Pure currentness evaluation for `Kiln.Evidence` records (P1-S02-T01-R09, R10,
  R15).

  `evaluate/2` accepts at most 256 immutable candidate records plus a typed
  `Context`. It returns a list of `Kiln.Evidence.View` values, one per
  candidate, derived without mutation, persistence, filesystem, clock, or
  process access. Time values carried by the Context are accepted as
  provenance but never determine freshness.

  ## Behavior

    * `freshness = :stale` — required binding mismatch, or explicit
      `invalidated_at` provided.
    * `freshness = :unknown` — a required binding or Artifact integrity
      observation is unavailable, or the freshness rule is unknown.
    * `freshness = :current` — every required binding matches, every
      referenced Artifact integrity is `:verified`, and the freshness rule
      is satisfied.
    * `contradiction = :present` — the candidate is `:current` and
      `:complete` with `result` in `{pass, fail}` and at least one other
      current complete pass/fail candidate shares criterion revision,
      subject tuple, Repository state, and nullable Patch binding.
    * `contradiction = :unknown` — freshness is `:stale` or `:unknown`.
    * `contradiction = :none` — otherwise.

  More than 256 candidates returns
  `{:error, %Kiln.Store.Error{class: :precondition, code: :limit_exceeded}}`
  and no partial view.

  ## Candidate limits

    * Maximum candidates: 256.
    * Maximum contradicting Evidence IDs per view: 256.
  """

  alias Kiln.Evidence
  alias Kiln.Evidence.{Currentness, View}
  alias Kiln.Store.Error

  @max_candidates 256
  @max_contradicting_ids 256

  @type result :: {:ok, [View.t()]} | {:error, Error.t()}

  @doc """
  Evaluate `candidates` against the supplied `Context`.
  """
  @spec evaluate([Evidence.t()], Currentness.Context.t()) :: result()
  def evaluate(candidates, %Currentness.Context{} = context) do
    if length(candidates) > @max_candidates do
      {:error,
       Error.new(
         :precondition,
         :limit_exceeded,
         "currentness accepts at most #{@max_candidates} candidate records",
         %{max: @max_candidates, actual: length(candidates)}
       )}
    else
      candidates_list = Enum.to_list(candidates)

      freshness_per_id =
        Map.new(candidates_list, fn candidate ->
          {candidate.evidence_id, classify_freshness(candidate, context)}
        end)

      contradiction_groups =
        build_contradiction_groups(candidates_list, freshness_per_id, context)

      views =
        Enum.map(candidates_list, fn candidate ->
          freshness = Map.fetch!(freshness_per_id, candidate.evidence_id)
          contradiction = contradiction_for(candidate, freshness, contradiction_groups)

          contradicting_ids =
            contradiction_ids_for(candidate, freshness, contradiction_groups)

          View.from_evidence(candidate,
            freshness: freshness,
            contradiction: contradiction,
            invalidated_at: invalidated_at(context, candidate),
            contradicting_evidence_ids: contradicting_ids
          )
        end)

      {:ok, views}
    end
  end

  defp classify_freshness(candidate, context) do
    cond do
      not is_nil(context.invalidated_at) ->
        :stale

      artifact_integrity_unavailable?(candidate, context) ->
        :unknown

      not binding_matches?(candidate, context, :subject_state_digest) ->
        :stale

      not binding_matches?(candidate, context, :repository_state_digest) ->
        :stale

      not binding_matches?(candidate, context, :evaluator_digest) ->
        :stale

      candidate.freshness_rule == :same_patch_and_repository_state and
          (candidate.patch_id != context.current_patch_id or
             candidate.patch_digest != context.current_patch_digest or
             candidate.patch_result_digest != context.current_patch_result_digest) ->
        :stale

      candidate.freshness_rule == :same_command_registration_and_repository_state and
          (candidate.command_registration_digest !=
             context.current_command_registration_digest or
             candidate.command_result_id != context.current_command_result_id) ->
        :stale

      true ->
        :current
    end
  end

  defp artifact_integrity_unavailable?(candidate, context) do
    Enum.any?(candidate.artifact_ids, fn artifact_id ->
      case Map.get(context.artifact_integrity_by_id, artifact_id, :__missing__) do
        :verified -> false
        _ -> true
      end
    end)
  end

  defp binding_matches?(candidate, context, field) when field == :subject_state_digest do
    candidate.subject_state_digest == context.current_subject_state_digest
  end

  defp binding_matches?(candidate, context, field) when field == :repository_state_digest do
    candidate.repository_state_digest == context.current_repository_state_digest
  end

  defp binding_matches?(candidate, context, field) when field == :evaluator_digest do
    candidate.evaluator_digest == context.current_evaluator_digest
  end

  defp build_contradiction_groups(candidates, freshness_per_id, _context) do
    eligible =
      Enum.filter(candidates, fn candidate ->
        Map.fetch!(freshness_per_id, candidate.evidence_id) == :current and
          candidate.result in [:pass, :fail] and
          candidate.completeness == :complete
      end)

    Enum.group_by(eligible, &contradiction_key/1)
  end

  defp contradiction_key(candidate) do
    {
      candidate.criterion_id,
      candidate.criterion_revision,
      candidate.subject_kind,
      candidate.subject_id,
      candidate.subject_state_digest,
      candidate.repository_state_digest,
      candidate.patch_id,
      candidate.patch_digest,
      candidate.patch_result_digest
    }
  end

  defp contradiction_for(candidate, freshness, groups) do
    cond do
      freshness in [:stale, :unknown] ->
        :unknown

      candidate.result not in [:pass, :fail] ->
        :none

      candidate.completeness != :complete ->
        :none

      group_has_contradiction?(groups, candidate) ->
        :present

      true ->
        :none
    end
  end

  defp group_has_contradiction?(groups, candidate) do
    case Map.get(groups, contradiction_key(candidate)) do
      nil ->
        false

      members ->
        has_pass = Enum.any?(members, &(&1.result == :pass))
        has_fail = Enum.any?(members, &(&1.result == :fail))
        has_pass and has_fail
    end
  end

  defp contradiction_ids_for(candidate, freshness, groups) do
    case freshness do
      freshness when freshness in [:stale, :unknown] ->
        []

      _ ->
        case Map.get(groups, contradiction_key(candidate)) do
          nil ->
            []

          members ->
            members
            |> Enum.reject(&(&1.evidence_id == candidate.evidence_id))
            |> Enum.map(& &1.evidence_id)
            |> Enum.uniq()
            |> Enum.sort()
            |> Enum.take(@max_contradicting_ids)
        end
    end
  end

  defp invalidated_at(context, _candidate), do: context.invalidated_at
end
