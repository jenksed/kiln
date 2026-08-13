defmodule Kiln.RunResultEnvelope do
  @moduledoc """
  The narrow producer for `engineering-system/run-result-envelope/v0` values.

  `Kiln.RunResultEnvelope` builds the canonical envelope Kiln returns
  after supervising one Repository Recon Work Envelope. The envelope is
  constructed strictly from durable facts already persisted in Kiln's
  Store. It does **not** claim acceptance, correctness, or human
  approval.

  ## Required facts

    * `work_id` — from the accepted Work Envelope.
    * `run_id` — the durable Run identifier the supervisor bound.
    * `status` — `completed | blocked | cancelled | failed | unknown`.
    * `input_state` — `{base_commit, workspace_state_digest}` from the
      Work Envelope.
    * `final_state` — `{commit, workspace_state_digest}` derived from
      the durable Repository Observation and the producer's input.
    * `authority` — `{requested, granted, denied}` lists.
    * `effects` — observed effects (Artifact and Evidence identifiers).
    * `evidence` — Evidence identifiers bound to the Work.
    * `proof_obligations` — `{satisfied, unsatisfied, invalidated}`.
    * `unknowns` — explicit unknowns.
    * `recovery` — `null` in Wave 3 v0.
    * `acceptance_readiness` — `{ready: false, reasons}` until a later
      review explicitly flips readiness.

  `status = completed` describes Run lifecycle, not human acceptance.
  `acceptance_readiness.ready = true` does not mean the user accepted.
  The supervisor never manufactures success.
  """

  alias Kiln.Authority

  @schema "engineering-system/run-result-envelope/v0"

  @statuses ~w(completed blocked cancelled failed unknown)a

  @enforce_keys [
    :schema,
    :work_id,
    :run_id,
    :status,
    :input_state,
    :final_state,
    :authority,
    :effects,
    :evidence,
    :proof_obligations,
    :unknowns,
    :recovery,
    :acceptance_readiness
  ]

  defstruct [
    :schema,
    :work_id,
    :run_id,
    :status,
    :input_state,
    :final_state,
    :authority,
    :effects,
    :evidence,
    :proof_obligations,
    :unknowns,
    :recovery,
    :acceptance_readiness
  ]

  @type status :: :completed | :blocked | :cancelled | :failed | :unknown

  @type t :: %__MODULE__{
          schema: String.t(),
          work_id: String.t(),
          run_id: String.t(),
          status: status(),
          input_state: %{base_commit: String.t(), workspace_state_digest: String.t()},
          final_state: %{commit: String.t() | nil, workspace_state_digest: String.t()},
          authority: %{requested: [String.t()], granted: [String.t()], denied: [String.t()]},
          effects: [map()],
          evidence: [map()],
          proof_obligations: %{
            satisfied: [String.t()],
            unsatisfied: [String.t()],
            invalidated: [String.t()]
          },
          unknowns: [String.t()],
          recovery: nil | map(),
          acceptance_readiness: %{ready: boolean(), reasons: [String.t()]}
        }

  @doc "The accepted Run Result Envelope v0 schema identifier."
  @spec schema() :: String.t()
  def schema, do: @schema

  @doc """
  Build a Run Result Envelope from durable supervised facts.

  Required options:

    * `:work_id` — the accepted Work Envelope `work_id`.
    * `:run_id` — the durable Run identifier.
    * `:status` — the supervisor lifecycle status.
    * `:input_state` — `%{base_commit, workspace_state_digest}` from the
      Work Envelope.
    * `:final_state` — `%{commit, workspace_state_digest}` from the
      observation and producer input.
    * `:authority_decisions` — a list of `%Kiln.Authority{}` records.
    * `:effects` — observed effects (e.g. Artifact ids, evidence ids).
    * `:evidence` — Evidence summaries keyed by `evidence_id`.
    * `:proof_obligations` — `%{satisfied, unsatisfied, invalidated}`.
    * `:unknowns` — list of explicit unknown strings.

  Acceptance readiness is always `false` in v0; the supervisor never
  claims the user accepted.
  """
  @spec build(keyword()) :: {:ok, t()} | {:error, term()}
  def build(opts) when is_list(opts) do
    work_id = Keyword.fetch!(opts, :work_id)
    run_id = Keyword.fetch!(opts, :run_id)
    status = Keyword.fetch!(opts, :status)
    input_state = Keyword.fetch!(opts, :input_state)
    final_state = Keyword.fetch!(opts, :final_state)
    authority_decisions = Keyword.fetch!(opts, :authority_decisions)
    effects = Keyword.get(opts, :effects, [])
    evidence = Keyword.get(opts, :evidence, [])
    proof_obligations = Keyword.get(opts, :proof_obligations, %{})
    unknowns = Keyword.get(opts, :unknowns, [])

    with :ok <- check_status(status),
         :ok <- check_input_state(input_state),
         :ok <- check_final_state(final_state),
         {:ok, authority} <- build_authority(authority_decisions),
         {:ok, proof_obligations} <- normalize_proof_obligations(proof_obligations) do
      envelope = %__MODULE__{
        schema: @schema,
        work_id: work_id,
        run_id: run_id,
        status: status,
        input_state: input_state,
        final_state: final_state,
        authority: authority,
        effects: effects,
        evidence: evidence,
        proof_obligations: proof_obligations,
        unknowns: unknowns,
        recovery: nil,
        acceptance_readiness: %{
          ready: false,
          reasons: ["Wave 3 v0 envelopes never claim user acceptance"]
        }
      }

      {:ok, envelope}
    end
  end

  @doc """
  Return the canonical envelope shape bound to the v0 schema.

  The map is the same JSON/YAML shape the contract documents; the
  supervisor uses this map both for durable persistence and for the
  CLI emission.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = envelope) do
    %{
      "schema" => envelope.schema,
      "work_id" => envelope.work_id,
      "run_id" => envelope.run_id,
      "status" => Atom.to_string(envelope.status),
      "input_state" => envelope.input_state,
      "final_state" => envelope.final_state,
      "authority" => envelope.authority,
      "effects" => envelope.effects,
      "evidence" => envelope.evidence,
      "proof_obligations" => envelope.proof_obligations,
      "unknowns" => envelope.unknowns,
      "recovery" => nil,
      "acceptance_readiness" => %{
        "ready" => envelope.acceptance_readiness.ready,
        "reasons" => envelope.acceptance_readiness.reasons
      }
    }
  end

  # -- helpers --

  defp check_status(status) when status in @statuses, do: :ok

  defp check_status(_) do
    {:error, {:invalid_status, Enum.map(@statuses, &Atom.to_string/1)}}
  end

  defp check_input_state(%{base_commit: bc, workspace_state_digest: wd})
       when is_binary(bc) and is_binary(wd) and byte_size(bc) > 0 and byte_size(wd) > 0 do
    :ok
  end

  defp check_input_state(_) do
    {:error, :invalid_input_state}
  end

  defp check_final_state(%{commit: commit, workspace_state_digest: wd})
       when (is_binary(commit) or is_nil(commit)) and is_binary(wd) and byte_size(wd) > 0 do
    :ok
  end

  defp check_final_state(_) do
    {:error, :invalid_final_state}
  end

  defp build_authority(decisions) when is_list(decisions) do
    initial = %{requested: [], granted: [], denied: []}

    result =
      Enum.reduce(decisions, {:ok, initial}, fn decision, acc ->
        case acc do
          {:ok, map} ->
            map =
              case decision do
                %Authority{requested_capability: cap} ->
                  requested = ensure_unique(map.requested, cap)

                  map =
                    if decision.result == :granted do
                      Map.put(map, :granted, ensure_unique(map.granted, cap))
                    else
                      Map.put(map, :denied, ensure_unique(map.denied, cap))
                    end

                  Map.put(map, :requested, requested)

                _ ->
                  map
              end

            {:ok, map}

          {:error, _} = err ->
            err
        end
      end)

    case result do
      {:ok, map} ->
        {:ok,
         %{
           requested: Enum.sort(map.requested),
           granted: Enum.sort(map.granted),
           denied: Enum.sort(map.denied)
         }}

      {:error, _} = err ->
        err
    end
  end

  defp build_authority(_) do
    {:error, :invalid_authority_decisions}
  end

  defp ensure_unique(list, value) do
    if value in list, do: list, else: list ++ [value]
  end

  defp normalize_proof_obligations(obligations) when is_map(obligations) do
    satisfied = obligations |> Map.get(:satisfied, []) |> Enum.sort() |> Enum.uniq()
    unsatisfied = obligations |> Map.get(:unsatisfied, []) |> Enum.sort() |> Enum.uniq()
    invalidated = obligations |> Map.get(:invalidated, []) |> Enum.sort() |> Enum.uniq()

    {:ok,
     %{
       satisfied: satisfied,
       unsatisfied: unsatisfied,
       invalidated: invalidated
     }}
  end

  defp normalize_proof_obligations(_) do
    {:error, :invalid_proof_obligations}
  end
end
