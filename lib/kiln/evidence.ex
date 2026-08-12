defmodule Kiln.Evidence do
  @moduledoc """
  The immutable first-month Evidence record persisted by T01.

  An `Evidence` is a single criterion-observation binding:

    * `evidence_id` — an opaque caller-supplied UUIDv7 that identifies one
      immutable observation record.
    * `record_digest` — a schema-bound SHA-256 hex digest over the complete
      immutable Evidence payload, excluding `evidence_id`, `idempotency_key`,
      `request_digest`, and `record_digest` itself.
    * `request_digest` — a schema-bound digest over the canonical persistent
      record request, including the caller-supplied identifiers and time
      fields, but excluding separate admission and currentness contexts.
    * `subject_kind`, `subject_id`, `subject_state_digest` — the canonical
      subject tuple.
    * `producer_kind`, `producer_id` — the producer provenance.
    * `method` — the accepted observation method.
    * `result` — the first-month result vocabulary.
    * `repository_state_digest` — the Repository state at observation.
    * `patch_id | nil`, `patch_digest | nil`, `patch_result_digest | nil` —
      all null or all non-null.
    * `host_profile_digest | nil`, `command_registration_digest | nil`,
      `command_result_id | nil` — nullable binding slots; the method may
      require some of them to be non-null.
    * `artifact_ids` — a unique, ascending, sorted list of UUIDv7
      identifiers; empty when the observation retained no byte Artifact.
    * `evaluator_digest`, `observation_digest` — required digests.
    * `completeness` — the observation completeness vocabulary.
    * `freshness_rule` — exactly one of the four state-based rules.
    * `observed_at`, `recorded_at` — bounded time strings.
    * `rationale | nil` — bounded optional rationale.
    * `idempotency_key` — required unique key for replay and conflict
      classification.

  Persistence lives in `Kiln.Evidence.Store.record/2`; this module owns pure
  construction, validation, and the canonical digest computation that
  bounds and replay identity consume (P1-S02-T01-R05, R06, R07, R11, R15).
  """

  alias Kiln.Store.Error

  @schema "kiln.evidence/v1"

  @results ~w(pass fail blocked unknown)a
  @methods ~w(registered_command repository_observation deterministic_validator user_observation)a
  @subject_kinds ~w(session run operation patch command artifact evidence repository)a
  @producer_kinds ~w(command provider pack patch repository user deterministic_service)a
  @completeness_values ~w(complete partial truncated missing unknown)a
  @freshness_rules ~w(
    same_repository_state
    same_patch_and_repository_state
    same_command_registration_and_repository_state
    manual_same_repository_state
  )a

  @max_artifact_ids 32
  @max_warnings 64
  @max_warning_bytes 1024
  @max_aggregate_warning_bytes 16_384
  @max_rationale_bytes 8192
  @max_identifier_bytes 256
  @max_criterion_revision_bytes 64
  @max_recorded_at_bytes 64
  @max_canonical_request 65_536

  @enforce_keys [
    :evidence_id,
    :session_id,
    :run_id,
    :criterion_id,
    :criterion_revision,
    :subject_id,
    :subject_kind,
    :subject_state_digest,
    :producer_kind,
    :producer_id,
    :method,
    :result,
    :repository_state_digest,
    :patch_id,
    :patch_digest,
    :patch_result_digest,
    :host_profile_digest,
    :command_registration_digest,
    :command_result_id,
    :artifact_ids,
    :evaluator_digest,
    :observation_digest,
    :completeness,
    :freshness_rule,
    :observed_at,
    :recorded_at,
    :rationale,
    :schema,
    :idempotency_key,
    :request_digest,
    :record_digest
  ]

  defstruct [
    :evidence_id,
    :session_id,
    :run_id,
    :criterion_id,
    :criterion_revision,
    :subject_id,
    :subject_kind,
    :subject_state_digest,
    :producer_kind,
    :producer_id,
    :method,
    :result,
    :repository_state_digest,
    :patch_id,
    :patch_digest,
    :patch_result_digest,
    :host_profile_digest,
    :command_registration_digest,
    :command_result_id,
    :artifact_ids,
    :evaluator_digest,
    :observation_digest,
    :completeness,
    :freshness_rule,
    :observed_at,
    :recorded_at,
    :rationale,
    :schema,
    :idempotency_key,
    :request_digest,
    :record_digest
  ]

  @type result :: :pass | :fail | :blocked | :unknown
  @type method ::
          :registered_command
          | :repository_observation
          | :deterministic_validator
          | :user_observation
  @type subject_kind ::
          :session | :run | :operation | :patch | :command | :artifact | :evidence | :repository
  @type producer_kind ::
          :command | :provider | :pack | :patch | :repository | :user | :deterministic_service
  @type completeness :: :complete | :partial | :truncated | :missing | :unknown
  @type freshness_rule ::
          :same_repository_state
          | :same_patch_and_repository_state
          | :same_command_registration_and_repository_state
          | :manual_same_repository_state

  @type t :: %__MODULE__{
          evidence_id: String.t(),
          session_id: String.t(),
          run_id: String.t(),
          criterion_id: String.t(),
          criterion_revision: String.t(),
          subject_id: String.t(),
          subject_kind: subject_kind(),
          subject_state_digest: String.t(),
          producer_kind: producer_kind(),
          producer_id: String.t(),
          method: method(),
          result: result(),
          repository_state_digest: String.t(),
          patch_id: String.t() | nil,
          patch_digest: String.t() | nil,
          patch_result_digest: String.t() | nil,
          host_profile_digest: String.t() | nil,
          command_registration_digest: String.t() | nil,
          command_result_id: String.t() | nil,
          artifact_ids: [String.t()],
          evaluator_digest: String.t(),
          observation_digest: String.t(),
          completeness: completeness(),
          freshness_rule: freshness_rule(),
          observed_at: String.t(),
          recorded_at: String.t(),
          rationale: String.t() | nil,
          schema: String.t(),
          idempotency_key: String.t(),
          request_digest: String.t(),
          record_digest: String.t()
        }

  @doc """
  Construct and validate an Evidence from the given attributes.

  Returns `{:ok, evidence}` or a classified `Kiln.Store.Error`. All bounds,
  vocabularies, digest shapes, UUIDv7 identifier shapes, cross-field safety
  checks, and NUL/control-byte rejection are enforced here. The `:schema`
  slot is always set to `"kiln.evidence/v1"`; callers may pass `nil` or
  omit the field.
  """
  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attrs) when is_map(attrs) do
    with {:ok, normalized} <- normalize(attrs),
         {:ok, bare} <- build_record(normalized) do
      record = %{bare | schema: @schema, request_digest: nil, record_digest: nil}
      request_digest = request_digest(record)

      record =
        record
        |> Map.put(:request_digest, request_digest)
        |> compute_record_digest()

      {:ok, record}
    end
  end

  @doc "The accepted Evidence schema identifier."
  @spec schema() :: String.t()
  def schema, do: @schema

  @doc "Maximum number of Artifact IDs allowed per Evidence record."
  @spec max_artifact_ids() :: pos_integer()
  def max_artifact_ids, do: @max_artifact_ids

  @doc "Maximum number of warning entries allowed per Evidence record."
  @spec max_warnings() :: pos_integer()
  def max_warnings, do: @max_warnings

  @doc "Maximum bytes per warning entry."
  @spec max_warning_bytes() :: pos_integer()
  def max_warning_bytes, do: @max_warning_bytes

  @doc "Maximum aggregate bytes across all warning entries (aborting trigger)."
  @spec max_aggregate_warning_bytes() :: pos_integer()
  def max_aggregate_warning_bytes, do: @max_aggregate_warning_bytes

  @doc "Maximum bytes for an optional rationale."
  @spec max_rationale_bytes() :: pos_integer()
  def max_rationale_bytes, do: @max_rationale_bytes

  @doc "Maximum bytes for a canonical Evidence persistent request."
  @spec max_canonical_request() :: pos_integer()
  def max_canonical_request, do: @max_canonical_request

  @doc """
  Canonical persistent-request map for digest computation and replay identity.

  Returns the persisted field map excluding `record_digest`. The same
  representation feeds the canonical encoder for `request_digest` and the
  later schema-bound `record_digest`. Caller-supplied envelope fields
  (`evidence_id`, `idempotency_key`, `observed_at`, `recorded_at`) are the
  actual persistent values; nil placeholders are not substituted.
  """
  @spec canonical_map(t()) :: map()
  def canonical_map(%__MODULE__{} = record) do
    record
    |> Map.from_struct()
    |> Map.delete(:record_digest)
  end

  @doc """
  Compute the canonical request digest bound to the Evidence schema.

  Two requests with identical canonical bytes under the Evidence schema
  receive the same `request_digest`; the same bytes under a different
  schema would differ. The `request_digest` is what the Store uses for
  idempotency-key replay and conflict classification.
  """
  @spec request_digest(t()) :: String.t()
  def request_digest(%__MODULE__{} = record) do
    record
    |> canonical_map()
    |> stringify_values()
    |> then(&Kiln.Store.Canonical.digest(@schema, &1))
  end

  @doc """
  True when `value` is the Evidence schema identifier.
  """
  @spec schema?(term()) :: boolean()
  def schema?(@schema), do: true
  def schema?(_), do: false

  # -- internal validation --

  defp normalize(attrs) do
    case check_required(attrs) do
      :ok -> {:ok, attrs}
      {:missing, key} -> {:error, missing_error(key)}
    end
  end

  defp check_required(attrs) do
    [
      :evidence_id,
      :session_id,
      :run_id,
      :criterion_id,
      :criterion_revision,
      :subject_id,
      :subject_kind,
      :subject_state_digest,
      :producer_kind,
      :producer_id,
      :method,
      :result,
      :repository_state_digest,
      :artifact_ids,
      :evaluator_digest,
      :observation_digest,
      :completeness,
      :freshness_rule,
      :observed_at,
      :recorded_at,
      :idempotency_key
    ]
    |> Enum.reduce_while(:ok, fn key, acc ->
      case Map.fetch(attrs, key) do
        {:ok, _} -> {:cont, acc}
        :error -> {:halt, {:missing, key}}
      end
    end)
  end

  defp missing_error(key) do
    Error.new(
      :precondition,
      :missing_field,
      "evidence request is missing a required field",
      %{field: key}
    )
  end

  defp build_record(attrs) do
    with {:ok, evidence_id} <- check_uuid_v7(attrs, :evidence_id),
         {:ok, session_id} <- check_identifier(attrs, :session_id),
         {:ok, run_id} <- check_identifier(attrs, :run_id),
         {:ok, criterion_id} <- check_identifier(attrs, :criterion_id),
         {:ok, criterion_revision} <-
           check_bounded_text(attrs, :criterion_revision, @max_criterion_revision_bytes),
         {:ok, subject_id} <- check_identifier(attrs, :subject_id),
         {:ok, subject_kind} <- check_enum(attrs, :subject_kind, @subject_kinds),
         {:ok, subject_state_digest} <- check_non_empty(attrs, :subject_state_digest),
         {:ok, producer_kind} <- check_enum(attrs, :producer_kind, @producer_kinds),
         {:ok, producer_id} <- check_identifier(attrs, :producer_id),
         {:ok, method} <- check_enum(attrs, :method, @methods),
         {:ok, result} <- check_enum(attrs, :result, @results),
         {:ok, repository_state_digest} <-
           check_non_empty(attrs, :repository_state_digest),
         {:ok, patch_id} <- check_optional_identifier(attrs, :patch_id),
         {:ok, patch_digest} <- check_optional_non_empty(attrs, :patch_digest),
         {:ok, patch_result_digest} <- check_optional_non_empty(attrs, :patch_result_digest),
         {:ok, host_profile_digest} <-
           check_optional_non_empty(attrs, :host_profile_digest),
         {:ok, command_registration_digest} <-
           check_optional_non_empty(attrs, :command_registration_digest),
         {:ok, command_result_id} <-
           check_optional_identifier(attrs, :command_result_id),
         {:ok, artifact_ids} <- check_artifact_ids(attrs),
         {:ok, evaluator_digest} <- check_non_empty(attrs, :evaluator_digest),
         {:ok, observation_digest} <- check_non_empty(attrs, :observation_digest),
         {:ok, completeness} <- check_enum(attrs, :completeness, @completeness_values),
         {:ok, freshness_rule} <- check_enum(attrs, :freshness_rule, @freshness_rules),
         {:ok, observed_at} <- check_bounded_text(attrs, :observed_at, @max_recorded_at_bytes),
         {:ok, recorded_at} <- check_bounded_text(attrs, :recorded_at, @max_recorded_at_bytes),
         {:ok, rationale} <- check_optional_rationale(attrs),
         {:ok, idempotency_key} <- check_identifier(attrs, :idempotency_key),
         :ok <-
           validate_cross_fields(
             method,
             result,
             completeness,
             patch_id,
             patch_digest,
             patch_result_digest,
             host_profile_digest,
             command_registration_digest,
             command_result_id
           ) do
      {:ok,
       %__MODULE__{
         evidence_id: evidence_id,
         session_id: session_id,
         run_id: run_id,
         criterion_id: criterion_id,
         criterion_revision: criterion_revision,
         subject_id: subject_id,
         subject_kind: subject_kind,
         subject_state_digest: subject_state_digest,
         producer_kind: producer_kind,
         producer_id: producer_id,
         method: method,
         result: result,
         repository_state_digest: repository_state_digest,
         patch_id: patch_id,
         patch_digest: patch_digest,
         patch_result_digest: patch_result_digest,
         host_profile_digest: host_profile_digest,
         command_registration_digest: command_registration_digest,
         command_result_id: command_result_id,
         artifact_ids: artifact_ids,
         evaluator_digest: evaluator_digest,
         observation_digest: observation_digest,
         completeness: completeness,
         freshness_rule: freshness_rule,
         observed_at: observed_at,
         recorded_at: recorded_at,
         rationale: rationale,
         schema: @schema,
         idempotency_key: idempotency_key,
         request_digest: nil,
         record_digest: nil
       }}
    end
  end

  defp validate_cross_fields(
         method,
         result,
         completeness,
         patch_id,
         patch_digest,
         patch_result_digest,
         host_profile_digest,
         command_registration_digest,
         command_result_id
       ) do
    cond do
      result in [:pass, :fail] and completeness != :complete ->
        {:error,
         Error.new(
           :precondition,
           :incomplete_proof,
           "pass or fail evidence requires completeness = complete",
           %{result: result, completeness: completeness}
         )}

      not patch_fields_consistent?(patch_id, patch_digest, patch_result_digest) ->
        {:error,
         Error.new(
           :precondition,
           :inconsistent_patch_binding,
           "patch_id, patch_digest, and patch_result_digest must all be null or all non-null",
           %{}
         )}

      method == :registered_command and
          (command_registration_digest == nil or command_result_id == nil or
             host_profile_digest == nil) ->
        {:error,
         Error.new(
           :precondition,
           :missing_command_binding,
           "registered_command evidence requires command_registration_digest, command_result_id, and host_profile_digest",
           %{}
         )}

      true ->
        :ok
    end
  end

  defp patch_fields_consistent?(nil, nil, nil), do: true

  defp patch_fields_consistent?(id, digest, result_digest)
       when is_binary(id) and is_binary(digest) and is_binary(result_digest),
       do: true

  defp patch_fields_consistent?(_, _, _), do: false

  defp check_uuid_v7(attrs, key) do
    value = Map.fetch!(attrs, key)

    if uuid_v7?(value) do
      {:ok, value}
    else
      {:error,
       Error.new(:precondition, :malformed_uuid_v7, "expected a UUIDv7 identifier", %{
         field: key,
         value: nil
       })}
    end
  end

  defp uuid_v7?(value) when is_binary(value) and byte_size(value) == 36 do
    case value |> String.split("-") do
      [a, b, c, d, e] ->
        byte_size(a) == 8 and byte_size(b) == 4 and byte_size(c) == 4 and byte_size(d) == 4 and
          byte_size(e) == 12 and Regex.match?(~r/^[0-9a-f]+$/, a) and
          Regex.match?(~r/^[0-9a-f]+$/, b) and Regex.match?(~r/^[0-9a-f]+$/, c) and
          Regex.match?(~r/^[0-9a-f]+$/, d) and Regex.match?(~r/^[0-9a-f]+$/, e) and
          String.starts_with?(c, "7") and variant_high?(d)

      _ ->
        false
    end
  end

  defp uuid_v7?(_), do: false

  defp variant_high?(d) when byte_size(d) == 4 do
    <<first::utf8, _::binary>> = d
    first in [?8, ?9, ?a, ?b]
  end

  defp check_identifier(attrs, key) do
    value = Map.fetch!(attrs, key)
    check_identifier_value(value, key)
  end

  defp check_optional_identifier(attrs, key) do
    case Map.get(attrs, key) do
      nil -> {:ok, nil}
      value -> check_identifier_value(value, key)
    end
  end

  defp check_identifier_value(value, key) when is_binary(value) do
    cond do
      byte_size(value) == 0 ->
        {:error,
         Error.new(
           :precondition,
           :empty_identifier,
           "identifier must not be empty",
           %{field: key}
         )}

      byte_size(value) > @max_identifier_bytes ->
        {:error, limit_error(key, @max_identifier_bytes, byte_size(value))}

      has_disallowed_control?(value) ->
        {:error,
         Error.new(
           :precondition,
           :disallowed_control_byte,
           "identifier contains a NUL or disallowed control byte",
           %{field: key}
         )}

      true ->
        {:ok, value}
    end
  end

  defp check_identifier_value(_, key) do
    {:error, Error.new(:precondition, :wrong_type, "identifier must be a binary", %{field: key})}
  end

  defp check_bounded_text(attrs, key, max) do
    value = Map.fetch!(attrs, key)

    case value do
      v when is_binary(v) ->
        cond do
          byte_size(v) == 0 ->
            {:error,
             Error.new(
               :precondition,
               :empty_text,
               "text field must not be empty",
               %{field: key}
             )}

          byte_size(v) > max ->
            {:error, limit_error(key, max, byte_size(v))}

          has_disallowed_control?(v) ->
            {:error,
             Error.new(
               :precondition,
               :disallowed_control_byte,
               "text field contains a NUL or disallowed control byte",
               %{field: key}
             )}

          true ->
            {:ok, v}
        end

      _ ->
        {:error,
         Error.new(:precondition, :wrong_type, "text field must be a binary", %{field: key})}
    end
  end

  defp check_non_empty(attrs, key) do
    value = Map.fetch!(attrs, key)

    case value do
      v when is_binary(v) ->
        if byte_size(v) == 0 do
          {:error,
           Error.new(
             :precondition,
             :empty_text,
             "required digest field must not be empty",
             %{field: key}
           )}
        else
          {:ok, v}
        end

      _ ->
        {:error,
         Error.new(:precondition, :wrong_type, "digest field must be a binary", %{field: key})}
    end
  end

  defp check_optional_non_empty(attrs, key) do
    case Map.get(attrs, key) do
      nil ->
        {:ok, nil}

      value when is_binary(value) ->
        if byte_size(value) == 0 do
          {:error,
           Error.new(
             :precondition,
             :empty_text,
             "optional field must not be empty when present",
             %{field: key}
           )}
        else
          {:ok, value}
        end

      _ ->
        {:error,
         Error.new(:precondition, :wrong_type, "optional field must be a binary or nil", %{
           field: key
         })}
    end
  end

  defp check_optional_rationale(attrs) do
    case Map.get(attrs, :rationale) do
      nil ->
        {:ok, nil}

      value when is_binary(value) ->
        cond do
          byte_size(value) == 0 ->
            {:error,
             Error.new(
               :precondition,
               :empty_text,
               "rationale must not be empty when present",
               %{}
             )}

          byte_size(value) > @max_rationale_bytes ->
            {:error, limit_error(:rationale, @max_rationale_bytes, byte_size(value))}

          has_disallowed_control?(value) ->
            {:error,
             Error.new(
               :precondition,
               :disallowed_control_byte,
               "rationale contains a NUL or disallowed control byte",
               %{}
             )}

          true ->
            {:ok, value}
        end

      _ ->
        {:error, Error.new(:precondition, :wrong_type, "rationale must be a binary or nil", %{})}
    end
  end

  defp check_enum(attrs, key, allowed) do
    value = Map.fetch!(attrs, key)

    if value in allowed do
      {:ok, value}
    else
      {:error,
       Error.new(
         :precondition,
         :invalid_vocabulary,
         "value is not in the accepted vocabulary",
         %{field: key, value: nil, allowed: allowed}
       )}
    end
  end

  defp check_artifact_ids(attrs) do
    value = Map.fetch!(attrs, :artifact_ids)

    cond do
      not is_list(value) ->
        {:error,
         Error.new(
           :precondition,
           :wrong_type,
           "artifact_ids must be a list",
           %{field: :artifact_ids}
         )}

      length(value) > @max_artifact_ids ->
        {:error,
         Error.new(
           :precondition,
           :limit_exceeded,
           "artifact_ids exceed the accepted count",
           %{max: @max_artifact_ids, actual: length(value)}
         )}

      not Enum.all?(value, &uuid_v7?/1) ->
        {:error,
         Error.new(
           :precondition,
           :malformed_uuid_v7,
           "every artifact_id must be a UUIDv7 identifier",
           %{field: :artifact_ids}
         )}

      has_duplicates?(value) ->
        {:error,
         Error.new(
           :precondition,
           :duplicate_artifact_id,
           "artifact_ids must be unique",
           %{}
         )}

      value != Enum.sort(value) ->
        {:error,
         Error.new(
           :precondition,
           :unsorted_artifact_ids,
           "artifact_ids must be sorted ascending",
           %{}
         )}

      true ->
        {:ok, value}
    end
  end

  defp has_duplicates?(list) do
    list
    |> Enum.frequencies()
    |> Enum.any?(fn {_, count} -> count > 1 end)
  end

  defp compute_record_digest(record) do
    # record_digest covers the complete immutable Evidence payload excluding
    # `evidence_id`, `idempotency_key`, `request_digest`, and `record_digest`.
    # Two records with the same binding content but distinct identifiers or
    # request digests therefore receive the same record_digest.
    canonical =
      record
      |> Map.from_struct()
      |> Map.drop([:evidence_id, :idempotency_key, :request_digest, :record_digest])
      |> stringify_values()

    Map.put(record, :record_digest, Kiln.Store.Canonical.digest(@schema, canonical))
  end

  defp stringify_values(value) when is_map(value) do
    Map.new(value, fn {k, v} -> {k, stringify_values(v)} end)
  end

  defp stringify_values(value) when is_list(value), do: Enum.map(value, &stringify_values/1)

  defp stringify_values(value)
       when is_atom(value) and value not in [nil, true, false],
       do: Atom.to_string(value)

  defp stringify_values(value), do: value

  defp has_disallowed_control?(value) when is_binary(value) do
    value
    |> :binary.bin_to_list()
    |> Enum.any?(&disallowed_control?/1)
  end

  defp disallowed_control?(byte) when byte < 0x20, do: true
  defp disallowed_control?(0x7F), do: true
  defp disallowed_control?(_), do: false

  defp limit_error(field, max, actual) do
    Error.new(
      :precondition,
      :limit_exceeded,
      "field exceeds the accepted byte bound",
      %{field: field, max: max, actual: actual}
    )
  end
end
