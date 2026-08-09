defmodule Kiln.Evidence do
  @moduledoc """
  Typed Evidence construction for kiln-state/v1.

  `new/1` validates the bounded vocabulary (subject_kind, producer_kind,
  method, freshness_class, completeness_class) and the freshness-TTL
  constraint, then computes a deterministic canonical digest over the
  canonical bytes of the struct (schema-bound). The same struct values
  always produce the same `evidence_id`; different values produce a
  different `evidence_id`. The protected `replay_attack` fixture relies
  on this property.

  The Evidence struct is the canonical source of identity. The digest is
  what the store records. The Evidence module never persists directly;
  that responsibility belongs to a later ticket's Gate execution path.

  No process, registry, or capability surface is introduced. No nested
  transaction or savepoint machinery is used.
  """

  alias Kiln.Evidence.{Completeness, Freshness}

  @subject_kinds [:session, :run, :operation, :patch, :command, :artifact, :evidence, :repository]
  @producer_kinds [:command, :provider, :pack, :patch, :script, :internal]
  @methods [:observed, :derived, :computed, :reported]
  @evidence_schema "kiln.evidence/v1"

  @type subject_kind ::
          :session
          | :run
          | :operation
          | :patch
          | :command
          | :artifact
          | :evidence
          | :repository

  @type producer_kind :: :command | :provider | :pack | :patch | :script | :internal
  @type method :: :observed | :derived | :computed | :reported

  @type t :: %__MODULE__{
          subject_id: String.t(),
          subject_kind: subject_kind(),
          subject_state_digest: String.t(),
          producer_kind: producer_kind(),
          producer_id: String.t(),
          method: method(),
          freshness_class: Freshness.t(),
          freshness_ttl_seconds: non_neg_integer() | nil,
          completeness_class: Completeness.t(),
          observed_at: String.t(),
          recorded_at: String.t(),
          artifact_id: String.t() | nil,
          schema: String.t(),
          evidence_id: String.t()
        }

  @enforce_keys [
    :subject_id,
    :subject_kind,
    :subject_state_digest,
    :producer_kind,
    :producer_id,
    :method,
    :freshness_class,
    :freshness_ttl_seconds,
    :completeness_class,
    :observed_at,
    :recorded_at,
    :artifact_id,
    :schema,
    :evidence_id
  ]
  defstruct @enforce_keys

  @doc "The complete accepted subject-kind set."
  @spec subject_kinds() :: [subject_kind()]
  def subject_kinds, do: @subject_kinds

  @doc "The complete accepted producer-kind set."
  @spec producer_kinds() :: [producer_kind()]
  def producer_kinds, do: @producer_kinds

  @doc "The complete accepted method set."
  @spec methods() :: [method()]
  def methods, do: @methods

  @doc "The accepted Evidence schema identifier."
  @spec schema() :: String.t()
  def schema, do: @evidence_schema

  @doc """
  Build one typed Evidence struct.

  Required fields (in `attrs`):

      :subject_id             — opaque identifier for the subject
      :subject_kind           — bounded atom (see `subject_kinds/0`)
      :subject_state_digest   — sha256:<64 hex> digest of the subject state
                                the Evidence is bound to
      :producer_kind          — bounded atom (see `producer_kinds/0`)
      :producer_id            — opaque producer identifier
      :method                 — bounded atom (see `methods/0`)
      :freshness_class        — bounded atom (see `Freshness.classes/0`)
      :freshness_ttl_seconds  — non-negative integer OR nil (`:durable`)
      :completeness_class     — bounded atom (see `Completeness.classes/0`)
      :observed_at            — ISO 8601 string
      :recorded_at            — ISO 8601 string
      :artifact_id            — `sha256:<64 hex>` digest OR nil

  Returns `{:ok, %__MODULE__{}}` on success. Returns `{:error,
  %Kiln.Store.Error{class: :evidence}}` for any bounded vocabulary
  rejection or constraint violation.
  """
  @spec new(map()) :: {:ok, t()} | {:error, Kiln.Store.Error.t()}
  def new(attrs) when is_map(attrs) do
    with {:ok, subject_id} <- nonempty(:subject_id, Map.get(attrs, :subject_id)),
         {:ok, subject_kind} <-
           member(:subject_kind, Map.get(attrs, :subject_kind), @subject_kinds),
         {:ok, subject_state_digest} <-
           digest_format(:subject_state_digest, Map.get(attrs, :subject_state_digest)),
         {:ok, producer_kind} <-
           member(:producer_kind, Map.get(attrs, :producer_kind), @producer_kinds),
         {:ok, producer_id} <- nonempty(:producer_id, Map.get(attrs, :producer_id)),
         {:ok, method} <- member(:method, Map.get(attrs, :method), @methods),
         {:ok, freshness_class} <-
           member(:freshness_class, Map.get(attrs, :freshness_class), Freshness.classes()),
         {:ok, freshness_ttl_seconds} <-
           validate_ttl(Map.get(attrs, :freshness_ttl_seconds), Map.get(attrs, :freshness_class)),
         {:ok, completeness_class} <-
           member(
             :completeness_class,
             Map.get(attrs, :completeness_class),
             Completeness.classes()
           ),
         {:ok, observed_at} <- nonempty(:observed_at, Map.get(attrs, :observed_at)),
         {:ok, recorded_at} <- nonempty(:recorded_at, Map.get(attrs, :recorded_at)),
         {:ok, artifact_id} <- optional_artifact_id(Map.get(attrs, :artifact_id)) do
      canonical =
        canonical_map(%{
          subject_id: subject_id,
          subject_kind: subject_kind,
          subject_state_digest: subject_state_digest,
          producer_kind: producer_kind,
          producer_id: producer_id,
          method: method,
          freshness_class: freshness_class,
          freshness_ttl_seconds: freshness_ttl_seconds,
          completeness_class: completeness_class,
          observed_at: observed_at,
          recorded_at: recorded_at,
          artifact_id: artifact_id
        })

      evidence_id = canonical_digest(canonical)

      {:ok,
       %__MODULE__{
         subject_id: subject_id,
         subject_kind: subject_kind,
         subject_state_digest: subject_state_digest,
         producer_kind: producer_kind,
         producer_id: producer_id,
         method: method,
         freshness_class: freshness_class,
         freshness_ttl_seconds: freshness_ttl_seconds,
         completeness_class: completeness_class,
         observed_at: observed_at,
         recorded_at: recorded_at,
         artifact_id: artifact_id,
         schema: @evidence_schema,
         evidence_id: evidence_id
       }}
    end
  end

  @doc "Lowercase hex SHA-256 digest over the canonical bytes of `evidence_map`, with the `sha256:` scheme prefix."
  @spec canonical_digest(map()) :: String.t()
  def canonical_digest(evidence_map) when is_map(evidence_map) do
    "sha256:" <>
      (:sha256
       |> :crypto.hash([@evidence_schema, "\n", canonical_bytes(evidence_map)])
       |> Base.encode16(case: :lower))
  end

  @doc "The canonical-byte representation of `evidence_map`, computed by `Kiln.Store.Canonical`."
  @spec canonical_bytes(map()) :: String.t()
  def canonical_bytes(evidence_map) when is_map(evidence_map) do
    Kiln.Store.Canonical.encode(evidence_map)
  end

  # -- internals --

  defp canonical_map(%{} = attrs) do
    # Canonical JSON encoding accepts only JSON-scalar values; bounded atom
    # vocabularies (subject_kind, producer_kind, method, freshness_class,
    # completeness_class) are coerced to their string form so the canonical
    # bytes reflect the logical identity, not the Elixir in-memory shape.
    attrs
    |> Map.new(fn {key, value} -> {key, atom_to_string(value)} end)
    |> Enum.sort_by(fn {key, _} -> Atom.to_string(key) end)
    |> Enum.into(%{})
  end

  defp atom_to_string(value) when is_atom(value) and not is_boolean(value) and value != nil,
    do: Atom.to_string(value)

  defp atom_to_string(value), do: value

  defp validate_ttl(ttl, freshness_class) do
    cond do
      freshness_class in [:transient, :stable] and (not is_integer(ttl) or ttl < 0) ->
        {:error,
         error(
           :freshness_ttl_seconds,
           ttl,
           "must be a non-negative integer when freshness_class is #{inspect(freshness_class)}"
         )}

      freshness_class == :durable and ttl != nil ->
        {:error,
         error(:freshness_ttl_seconds, ttl, "must be nil when freshness_class is :durable")}

      true ->
        {:ok, ttl}
    end
  end

  defp optional_artifact_id(nil), do: {:ok, nil}

  defp optional_artifact_id("sha256:" <> hex) when byte_size(hex) == 64 do
    if hex =~ ~r/^[0-9a-f]{64}$/ do
      {:ok, "sha256:" <> hex}
    else
      {:error, error(:artifact_id, "sha256:" <> hex, "must be sha256:<64 lowercase hex chars>")}
    end
  end

  defp optional_artifact_id(other) do
    {:error, error(:artifact_id, other, "must be sha256:<64 lowercase hex chars> or nil")}
  end

  defp nonempty(_field, value) when is_binary(value) and byte_size(value) > 0, do: {:ok, value}
  defp nonempty(field, value), do: {:error, error(field, value, "must be a non-empty string")}

  defp member(field, value, allowed) do
    if value in allowed do
      {:ok, value}
    else
      {:error, error(field, value, "must be one of #{inspect(allowed)}")}
    end
  end

  defp digest_format(field, "sha256:" <> hex) when byte_size(hex) == 64 do
    if hex =~ ~r/^[0-9a-f]{64}$/,
      do: {:ok, "sha256:" <> hex},
      else: {:error, error(field, "sha256:" <> hex, "must be sha256:<64 lowercase hex chars>")}
  end

  defp digest_format(field, value) do
    {:error, error(field, value, "must be sha256:<64 lowercase hex chars>")}
  end

  defp error(field, value, reason) do
    Kiln.Store.Error.new(
      :evidence,
      :invalid_field,
      "evidence field #{inspect(field)} rejected",
      %{
        field: field,
        value: value,
        reason: reason
      }
    )
  end
end
