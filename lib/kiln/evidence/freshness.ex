defmodule Kiln.Evidence.Freshness do
  @moduledoc """
  Bounded freshness vocabulary for typed Evidence rows.

  The three accepted freshness classes are:

      :transient — the Evidence is bounded by a freshness TTL in seconds.
        A `:transient` row MUST carry a non-nil `freshness_ttl_seconds`.
      :stable   — the Evidence has a bounded but longer effective lifetime.
        A `:stable` row MUST carry a non-nil `freshness_ttl_seconds`.
      :durable  — the Evidence is permanent and MUST carry nil
        `freshness_ttl_seconds`. Re-recording a `:durable` Evidence with
        mutated content fails the `replay_attack` fixture (see
        `Kiln.Artifact.Store`'s protected matrix).

  No process, registry, or capability surface is introduced.
  """

  @classes [:transient, :stable, :durable]

  @type t :: :transient | :stable | :durable

  @doc "The complete accepted freshness class set."
  @spec classes() :: [t()]
  def classes, do: @classes

  @doc "Whether `term` is an accepted freshness class."
  @spec member?(term()) :: boolean()
  def member?(term) when term in @classes, do: true
  def member?(_), do: false

  @doc "Return `term` unchanged when it is a freshness class, otherwise `:unknown`."
  @spec cast(term()) :: t() | :unknown
  def cast(term) when term in @classes, do: term
  def cast(_), do: :unknown

  @doc """
  Whether a row with `freshness_class` is required to carry a
  `freshness_ttl_seconds` value.

  `:transient` and `:stable` rows require a TTL; `:durable` rows require
  nil TTL. The constraint is enforced in `Kiln.Evidence.new/1` and as a
  CHECK constraint in migration `0004_evidence_records.sql`.
  """
  @spec ttl_required?(t()) :: boolean()
  def ttl_required?(:durable), do: false
  def ttl_required?(:transient), do: true
  def ttl_required?(:stable), do: true
end
