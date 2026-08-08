defmodule Kiln.Evidence.Completeness do
  @moduledoc """
  Bounded completeness vocabulary for typed Evidence rows.

  The three accepted completeness classes are:

      :complete   — the Evidence fully covers its declared subject and
        method. The protected failure matrix accepts this row without
        classification.
      :partial    — the Evidence covers a known partial subset of the
        subject; the producer declares so via the producer_id. Later
        criterion-bound Evidence (P1-S02-T06) may treat a `:partial`
        Evidence as non-blocking for the criterion it covers and blocked
        for any criterion it does not.
      :incomplete — the Evidence is structurally incomplete; the
        protected matrix classifies it `:incomplete` and refuses to treat
        it as supporting any criterion.

  No process, registry, or capability surface is introduced.
  """

  @classes [:complete, :partial, :incomplete]

  @type t :: :complete | :partial | :incomplete

  @doc "The complete accepted completeness class set."
  @spec classes() :: [t()]
  def classes, do: @classes

  @doc "Whether `term` is an accepted completeness class."
  @spec member?(term()) :: boolean()
  def member?(term) when term in @classes, do: true
  def member?(_), do: false

  @doc "Return `term` unchanged when it is a completeness class, otherwise `:unknown`."
  @spec cast(term()) :: t() | :unknown
  def cast(term) when term in @classes, do: term
  def cast(_), do: :unknown
end
