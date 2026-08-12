defmodule Kiln.Evidence.RecordRequest do
  @moduledoc """
  The typed request accepted by `Kiln.Evidence.Store.record/2`.

  A RecordRequest separates the immutable `evidence` payload from an
  `admission_context` used only for an unseen-key current-state precondition.
  `warnings` are bounded inputs to `evidence_warnings`; aggregate and per-item
  bounds are enforced here and re-enforced by the aborting SQLite trigger
  (P1-S02-T01-AC15).

  The `evidence` payload is constructed by `Kiln.Evidence.new/1` before this
  module completes validation, so downstream callers receive a fully valid
  Evidence struct plus the typed envelope fields.
  """

  alias Kiln.Evidence
  alias Kiln.Store.Error

  @enforce_keys [:evidence, :admission_context, :warnings]
  defstruct [:evidence, :admission_context, :warnings]

  @type t :: %__MODULE__{
          evidence: Evidence.t(),
          admission_context: map() | nil,
          warnings: [String.t()]
        }

  @doc """
  Construct and validate a RecordRequest from the given attributes.

  `attrs` must contain `:evidence` (a map of Evidence fields, validated by
  `Kiln.Evidence.new/1`), and may optionally include `:admission_context`
  (a map) and `:warnings` (a list of binaries). Defaults: `admission_context`
  is `nil`; `warnings` is `[]`.
  """
  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attrs) when is_map(attrs) do
    case Map.fetch(attrs, :evidence) do
      {:ok, evidence_attrs} when is_map(evidence_attrs) ->
        build(attrs, evidence_attrs)

      _ ->
        {:error,
         Error.new(
           :precondition,
           :missing_field,
           "record_request is missing the evidence payload",
           %{field: :evidence}
         )}
    end
  end

  defp build(attrs, evidence_attrs) do
    with {:ok, evidence} <- Evidence.new(evidence_attrs),
         {:ok, warnings} <- validate_warnings(Map.get(attrs, :warnings, [])),
         {:ok, admission_context} <-
           validate_admission_context(Map.get(attrs, :admission_context)) do
      {:ok,
       %__MODULE__{
         evidence: evidence,
         admission_context: admission_context,
         warnings: warnings
       }}
    end
  end

  defp validate_warnings(value) do
    cond do
      not is_list(value) ->
        {:error,
         Error.new(:precondition, :wrong_type, "warnings must be a list", %{
           field: :warnings
         })}

      length(value) > Evidence.max_warnings() ->
        {:error,
         Error.new(
           :precondition,
           :limit_exceeded,
           "warnings exceed the accepted count",
           %{max: Evidence.max_warnings(), actual: length(value)}
         )}

      not Enum.all?(value, &is_binary/1) ->
        {:error,
         Error.new(:precondition, :wrong_type, "every warning must be a binary", %{
           field: :warnings
         })}

      true ->
        case Enum.reduce_while(value, 0, &accumulate_warning/2) do
          {:error, _} = err ->
            err

          total ->
            if total <= Evidence.max_aggregate_warning_bytes() do
              {:ok, value}
            else
              {:error,
               Error.new(
                 :precondition,
                 :limit_exceeded,
                 "aggregate warnings exceed the 16384-byte trigger limit",
                 %{max: Evidence.max_aggregate_warning_bytes(), total: total}
               )}
            end
        end
    end
  end

  defp accumulate_warning(warning, total) do
    case validate_single_warning(warning, total) do
      :ok -> {:cont, total + byte_size(warning)}
      {:error, _} = err -> {:halt, err}
    end
  end

  defp validate_single_warning(warning, total) do
    cond do
      byte_size(warning) == 0 ->
        {:error,
         Error.new(
           :precondition,
           :empty_text,
           "warning must not be empty",
           %{}
         )}

      byte_size(warning) > Evidence.max_warning_bytes() ->
        {:error,
         Error.new(
           :precondition,
           :limit_exceeded,
           "warning exceeds the accepted byte bound",
           %{max: Evidence.max_warning_bytes(), actual: byte_size(warning)}
         )}

      total + byte_size(warning) > Evidence.max_aggregate_warning_bytes() ->
        {:error,
         Error.new(
           :precondition,
           :limit_exceeded,
           "aggregate warnings would exceed the 16384-byte trigger limit",
           %{max: Evidence.max_aggregate_warning_bytes(), total: total}
         )}

      has_disallowed_control?(warning) ->
        {:error,
         Error.new(
           :precondition,
           :disallowed_control_byte,
           "warning contains a NUL or disallowed control byte",
           %{}
         )}

      true ->
        :ok
    end
  end

  defp validate_admission_context(nil), do: {:ok, nil}

  defp validate_admission_context(value) when is_map(value) do
    allowed_keys = ~w(
      current_subject_state_digest
      current_repository_state_digest
      current_patch_id
      current_patch_digest
      current_patch_result_digest
      current_host_profile_digest
      current_command_registration_digest
      current_command_result_id
      current_evaluator_digest
      artifact_integrity_by_id
      invalidated_at
      evaluated_at
    )a

    case Enum.find(Map.keys(value), fn key -> key not in allowed_keys end) do
      nil ->
        {:ok, value}

      unknown ->
        {:error,
         Error.new(:precondition, :unknown_field, "admission_context carries an unknown field", %{
           field: unknown
         })}
    end
  end

  defp validate_admission_context(_) do
    {:error,
     Error.new(
       :precondition,
       :wrong_type,
       "admission_context must be a map or nil",
       %{}
     )}
  end

  defp has_disallowed_control?(value) when is_binary(value) do
    value
    |> :binary.bin_to_list()
    |> Enum.any?(&disallowed_control?/1)
  end

  defp disallowed_control?(byte) when byte < 0x20, do: true
  defp disallowed_control?(0x7F), do: true
  defp disallowed_control?(_), do: false
end
