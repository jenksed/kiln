defmodule Kiln.Authority do
  @moduledoc """
  The Wave 3 narrow authority decision boundary.

  `Kiln.Authority` is the sole authority decision surface in the Wave 3
  wedge. It accepts one `(Work, Run, authority_request, observation)` tuple
  and returns either `:granted` or `:denied` for **exactly one**
  authority capability: `git.read` on the target repository.

  Everything else is denied. The accepted authority set is fixed and
  authoritative; there is no general policy engine, no scope-expansion
  path, and no Loadout ontology import. The decision is recorded in a
  typed `Decision` value that the supervisor persists.

  ## Decision shape

    * `decision_id` — a unique UUIDv7 for the decision record.
    * `work_id` — the Work Envelope `work_id` this decision is bound to.
    * `run_id` — the Run this decision is bound to.
    * `requested_capability` — the producer's capability string.
    * `requested_scope` — the producer's scope string.
    * `granted_scope` — the actual scope Kiln granted, scoped to the
      observation's repository root.
    * `repository_state_digest` — the Kiln-observed repository state
      digest at decision time.
    * `result` — `:granted` or `:denied`.
    * `reason_code` — a stable atom describing why.
    * `decided_at` — the RFC 3339 decision time.

  A decision is durable. The supervisor persists it through the
  Artifact substrate (a `DecisionRecord` Artifact) and records the
  decision id on the resulting Evidence. Deleting Loadout's local
  presentation never erases the decision because Kiln is the source
  of truth.
  """

  alias Kiln.RepositoryObservation
  alias Kiln.Store.Error

  @schema "kiln.authority.decision/v1"

  @accepted_capability "git.read"

  @enforce_keys [
    :decision_id,
    :work_id,
    :run_id,
    :requested_capability,
    :requested_scope,
    :granted_scope,
    :repository_state_digest,
    :result,
    :reason_code,
    :decided_at,
    :schema
  ]

  defstruct [
    :decision_id,
    :work_id,
    :run_id,
    :requested_capability,
    :requested_scope,
    :granted_scope,
    :repository_state_digest,
    :result,
    :reason_code,
    :decided_at,
    :schema
  ]

  @type result :: :granted | :denied
  @type reason ::
          :unsupported_capability
          | :scope_mismatch
          | :repository_unavailable
          | :head_unresolved
          | :no_commit_binding
          | :granted

  @type t :: %__MODULE__{
          decision_id: String.t(),
          work_id: String.t(),
          run_id: String.t(),
          requested_capability: String.t(),
          requested_scope: String.t(),
          granted_scope: String.t() | nil,
          repository_state_digest: String.t(),
          result: result(),
          reason_code: reason(),
          decided_at: String.t(),
          schema: String.t()
        }

  @type decision_outcome :: {:ok, t()} | {:error, Error.t()}

  @doc "The only accepted authority capability in Wave 3."
  @spec accepted_capability() :: String.t()
  def accepted_capability, do: @accepted_capability

  @doc "The decision schema identifier."
  @spec schema() :: String.t()
  def schema, do: @schema

  @doc """
  Decide authority for one request.

  Required options:

    * `:work_id` — the Work Envelope `work_id`.
    * `:run_id` — the durable Run identifier this decision is bound to.
    * `:requested_capability` — the producer's capability string.
    * `:requested_scope` — the producer's scope string.
    * `:observation` — a `%Kiln.RepositoryObservation{}` produced before
      the decision was made.
    * `:base_commit` — the Work Envelope `project_state.base_commit`.
    * `:decision_id` — a UUIDv7 for this decision (caller-supplied).
    * `:now` — an RFC 3339 timestamp (caller-supplied for determinism).

  Returns a typed `Decision`. The decision is durable; the supervisor
  is responsible for persisting it.
  """
  @spec decide(keyword()) :: decision_outcome()
  def decide(opts) when is_list(opts) do
    work_id = Keyword.fetch!(opts, :work_id)
    run_id = Keyword.fetch!(opts, :run_id)
    requested_capability = Keyword.fetch!(opts, :requested_capability)
    requested_scope = Keyword.fetch!(opts, :requested_scope)
    observation = Keyword.fetch!(opts, :observation)
    base_commit = Keyword.fetch!(opts, :base_commit)
    decision_id = Keyword.fetch!(opts, :decision_id)
    now = Keyword.fetch!(opts, :now)

    with :ok <- check_observation(observation),
         :ok <- check_base_commit(base_commit) do
      result_and_reason =
        decide_inner(
          requested_capability,
          requested_scope,
          observation,
          base_commit
        )

      {result, reason, granted_scope} = result_and_reason

      decision = %__MODULE__{
        decision_id: decision_id,
        work_id: work_id,
        run_id: run_id,
        requested_capability: requested_capability,
        requested_scope: requested_scope,
        granted_scope: granted_scope,
        repository_state_digest: observation.repository_state_digest,
        result: result,
        reason_code: reason,
        decided_at: now,
        schema: @schema
      }

      {:ok, decision}
    end
  end

  @doc """
  Filter a list of authority requests, returning the subset that is
  granted for the given observation.

  Used by the supervisor to classify each
  `WorkEnvelope.authority_requests` entry. The filter accepts
  `git.read` whose `requested_scope` equals the observed repository
  root and whose `project_state.base_commit` equals the resolved
  `current_commit`. Every other request is denied.
  """
  @spec classify_requests([map()], RepositoryObservation.t(), String.t()) :: %{
          granted: [map()],
          denied: [map()]
        }
  def classify_requests(requests, %RepositoryObservation{} = observation, base_commit) do
    Enum.reduce(requests, %{granted: [], denied: []}, fn request, acc ->
      case request do
        %{"capability" => @accepted_capability, "scope" => scope}
        when is_binary(scope) ->
          if scope == observation.repository and observation.head_resolved and
               observation.current_commit == base_commit do
            Map.update!(acc, :granted, &[request | &1])
          else
            Map.update!(acc, :denied, &[request | &1])
          end

        _ ->
          Map.update!(acc, :denied, &[request | &1])
      end
    end)
  end

  # -- helpers --

  defp decide_inner(requested_capability, requested_scope, observation, base_commit) do
    cond do
      requested_capability != @accepted_capability ->
        {:denied, :unsupported_capability, nil}

      not observation.head_resolved ->
        {:denied, :head_unresolved, nil}

      requested_scope != observation.repository ->
        {:denied, :scope_mismatch, nil}

      observation.current_commit == nil or observation.current_commit != base_commit ->
        {:denied, :no_commit_binding, nil}

      true ->
        {:granted, :granted, observation.repository}
    end
  end

  defp check_observation(%RepositoryObservation{} = obs) do
    cond do
      not is_binary(obs.repository) or byte_size(obs.repository) == 0 ->
        {:error,
         Error.new(
           :precondition,
           :missing_repository,
           "observation is missing the repository root",
           %{}
         )}

      not is_binary(obs.repository_state_digest) or byte_size(obs.repository_state_digest) == 0 ->
        {:error,
         Error.new(
           :precondition,
           :missing_state_digest,
           "observation is missing the repository state digest",
           %{}
         )}

      true ->
        :ok
    end
  end

  defp check_observation(_) do
    {:error,
     Error.new(
       :precondition,
       :wrong_type,
       "observation must be a %Kiln.RepositoryObservation{}",
       %{}
     )}
  end

  defp check_base_commit(commit) when is_binary(commit) do
    if String.match?(commit, ~r/^[0-9a-f]{40}$/) do
      :ok
    else
      {:error,
       Error.new(
         :precondition,
         :invalid_base_commit,
         "base_commit must be a 40-character lowercase SHA",
         %{value: commit}
       )}
    end
  end

  defp check_base_commit(_) do
    {:error,
     Error.new(
       :precondition,
       :wrong_type,
       "base_commit must be a binary SHA",
       %{}
     )}
  end
end
