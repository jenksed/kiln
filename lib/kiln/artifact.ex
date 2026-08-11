defmodule Kiln.Artifact do
  @moduledoc """
  The immutable provenance-bearing Artifact record persisted by T01.

  An `Artifact` has two distinct identities:

    * `artifact_id` — an opaque caller-supplied UUIDv7 that identifies one
      provenance-bearing record;
    * `content_digest` — a SHA-256 digest over the exact stored bytes.

  Identical bytes may share one content-addressed blob while separate Artifact
  records preserve different owners, producers, bindings, sensitivity, or
  retention. Content bytes live below the accepted Artifact root, never in
  SQLite (P1-S02-T01-R01, R02).

  `Kiln.Artifact.Store.put/2` owns the publication path; this module owns pure
  construction and validation. A constructed record is plain data with no
  process, registry, or filesystem state.
  """

  alias Kiln.Store.Error

  @schema "kiln.artifact/v1"

  @owner_kinds ~w(project session run)a
  @producer_kinds ~w(command provider pack patch repository user deterministic_service)a
  @kinds ~w(input output report log snapshot patch diff summary other)a
  @encodings ~w(binary utf_8 utf_8_bom)a
  @trusts ~w(kiln_generated registered_command_output provider_output user_supplied repository_observation)a
  @sensitivities ~w(public project sensitive secret unknown)a
  @retention_classes ~w(run session project audit release policy_controlled)a
  @completeness_values ~w(complete partial truncated missing unknown)a

  @max_byte_size 16_777_216
  @max_canonical_request 65_536
  @max_identifier_bytes 256
  @max_media_type_bytes 255
  @max_relative_location_bytes 128

  @enforce_keys [
    :artifact_id,
    :session_id,
    :run_id,
    :owner_kind,
    :owner_id,
    :producer_kind,
    :producer_id,
    :kind,
    :media_type,
    :encoding,
    :content_digest,
    :byte_size,
    :content_location,
    :trust,
    :sensitivity,
    :retention_class,
    :completeness,
    :recorded_at,
    :schema,
    :idempotency_key,
    :request_digest
  ]

  defstruct [
    :artifact_id,
    :session_id,
    :run_id,
    :creator_operation_id,
    :owner_kind,
    :owner_id,
    :producer_kind,
    :producer_id,
    :kind,
    :media_type,
    :encoding,
    :content_digest,
    :byte_size,
    :content_location,
    :repository_state_digest,
    :host_profile_digest,
    :trust,
    :sensitivity,
    :retention_class,
    :completeness,
    :recorded_at,
    :schema,
    :idempotency_key,
    :request_digest
  ]

  @type owner_kind :: :project | :session | :run
  @type producer_kind ::
          :command | :provider | :pack | :patch | :repository | :user | :deterministic_service
  @type kind :: :input | :output | :report | :log | :snapshot | :patch | :diff | :summary | :other
  @type encoding :: :binary | :utf_8 | :utf_8_bom
  @type trust ::
          :kiln_generated
          | :registered_command_output
          | :provider_output
          | :user_supplied
          | :repository_observation
  @type sensitivity :: :public | :project | :sensitive | :secret | :unknown
  @type retention_class :: :run | :session | :project | :audit | :release | :policy_controlled
  @type completeness :: :complete | :partial | :truncated | :missing | :unknown

  @type t :: %__MODULE__{
          artifact_id: String.t(),
          session_id: String.t(),
          run_id: String.t(),
          creator_operation_id: String.t() | nil,
          owner_kind: owner_kind(),
          owner_id: String.t(),
          producer_kind: producer_kind(),
          producer_id: String.t(),
          kind: kind(),
          media_type: String.t(),
          encoding: encoding(),
          content_digest: String.t(),
          byte_size: non_neg_integer(),
          content_location: String.t(),
          repository_state_digest: String.t() | nil,
          host_profile_digest: String.t() | nil,
          trust: trust(),
          sensitivity: sensitivity(),
          retention_class: retention_class(),
          completeness: completeness(),
          recorded_at: String.t(),
          schema: String.t(),
          idempotency_key: String.t(),
          request_digest: String.t()
        }

  @doc """
  Construct and validate an Artifact from the given attributes.

  Returns `{:ok, artifact}` or a classified `Kiln.Store.Error`. All bounds,
  vocabularies, digest shapes, UUIDv7 identifier shapes, and NUL/control-byte
  rejection are enforced here. The `:schema` slot is always set to
  `"kiln.artifact/v1"`; callers may pass `nil` or omit the field.
  """
  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attrs) when is_map(attrs) do
    with {:ok, normalized} <- normalize(attrs),
         {:ok, record} <- build_record(normalized) do
      {:ok, %{record | schema: @schema}}
    end
  end

  @doc """
  Maximum bytes for one Artifact content blob.
  """
  @spec max_byte_size() :: pos_integer()
  def max_byte_size, do: @max_byte_size

  @doc """
  Maximum bytes for one canonical Artifact metadata request.
  """
  @spec max_canonical_request() :: pos_integer()
  def max_canonical_request, do: @max_canonical_request

  @doc """
  Canonical persistent-request map for digest computation and replay identity.

  Returns the persisted field map excluding `request_digest` itself. The same
  representation is used for byte-size enforcement, request_digest calculation,
  and replay identity so the three cannot drift.

  The caller-supplied envelope fields (`artifact_id`, `idempotency_key`,
  `recorded_at`) are the actual persistent values; nil placeholders are not
  substituted.
  """
  @spec canonical_map(t()) :: map()
  def canonical_map(%__MODULE__{} = record) do
    record
    |> Map.from_struct()
    |> Map.delete(:request_digest)
  end

  @doc """
  Byte size of the canonical request encoding.

  Used by the byte-size enforcement and by replay verification. Returns the
  exact byte count of `Kiln.Store.Canonical.encode/1` applied to the canonical
  map with atom vocabulary values stringified.
  """
  @spec canonical_byte_size(t()) :: non_neg_integer()
  def canonical_byte_size(%__MODULE__{} = record) do
    record
    |> canonical_map()
    |> stringify_values()
    |> Kiln.Store.Canonical.encode()
    |> byte_size()
  end

  @doc """
  Compute the canonical request digest bound to the Artifact schema.

  Two requests with identical canonical bytes under the Artifact schema receive
  the same digest; the same bytes under a different schema would differ.
  """
  @spec request_digest(t()) :: String.t()
  def request_digest(%__MODULE__{} = record) do
    record
    |> canonical_map()
    |> stringify_values()
    |> then(&Kiln.Store.Canonical.digest(@schema, &1))
  end

  @doc """
  Build the canonical persistent-request map from the caller's envelope and
  metadata, computing `content_digest`, `byte_size`, and `content_location`
  from `bytes`.

  Returns a single map with every persisted Artifact field except
  `request_digest`, ready for canonical-byte encoding. Atom vocabulary values
  are stringified in place. This is the same shape produced by `canonical_map/1`
  over a stored record so size enforcement, digest computation, and replay
  identity all read the identical representation.
  """
  @spec persistent_request_map(map(), keyword() | map()) :: map()
  def persistent_request_map(envelope, metadata)
      when is_map(envelope) and is_map(metadata) do
    bytes = Map.fetch!(envelope, :bytes)
    artifact_id = Map.fetch!(envelope, :artifact_id)
    idempotency_key = Map.fetch!(envelope, :idempotency_key)
    recorded_at = Map.fetch!(envelope, :recorded_at)

    content_digest = compute_content_digest(bytes)
    content_location = Kiln.Artifact.FS.content_location(content_digest)

    metadata
    |> stringify_values()
    |> Map.merge(%{
      schema: @schema,
      artifact_id: artifact_id,
      idempotency_key: idempotency_key,
      recorded_at: recorded_at,
      content_digest: content_digest,
      byte_size: byte_size(bytes),
      content_location: content_location
    })
  end

  defp compute_content_digest(bytes) when is_binary(bytes) do
    "sha256:" <> (:crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower))
  end

  defp stringify_values(value) when is_map(value) do
    Map.new(value, fn {k, v} -> {k, stringify_values(v)} end)
  end

  defp stringify_values(value) when is_list(value), do: Enum.map(value, &stringify_values/1)

  defp stringify_values(value)
       when is_atom(value) and value not in [nil, true, false],
       do: Atom.to_string(value)

  defp stringify_values(value), do: value

  @doc "The accepted Artifact schema identifier."
  @spec schema() :: String.t()
  def schema, do: @schema

  @doc "The maximum byte size for a content blob."
  @spec content_byte_limit() :: pos_integer()
  def content_byte_limit, do: @max_byte_size

  @doc "True when `value` is a UUIDv7 canonical lowercase string."
  @spec uuid_v7?(term()) :: boolean()
  def uuid_v7?(value) when is_binary(value) and byte_size(value) == 36 do
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

  def uuid_v7?(_), do: false

  # UUID variant bits live in the high two bits of the 4th group's first
  # nibble; RFC 4122 variants are 8, 9, a, or b. Anything else is rejected.
  defp variant_high?(d) when byte_size(d) == 4 do
    <<first::utf8, _::binary>> = d
    first in [?8, ?9, ?a, ?b]
  end

  # -- internal normalization --

  defp normalize(attrs) do
    case check_required(attrs) do
      :ok ->
        {:ok, attrs}

      {:missing, key} ->
        {:error, missing_error(key)}
    end
  end

  defp check_required(attrs) do
    [
      :artifact_id,
      :session_id,
      :run_id,
      :owner_kind,
      :owner_id,
      :producer_kind,
      :producer_id,
      :kind,
      :media_type,
      :encoding,
      :content_digest,
      :byte_size,
      :content_location,
      :trust,
      :sensitivity,
      :retention_class,
      :completeness,
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
      "artifact request is missing a required field",
      %{field: key}
    )
  end

  defp build_record(attrs) do
    with {:ok, artifact_id} <- check_uuid_v7(attrs, :artifact_id),
         {:ok, creator_operation_id} <- check_optional_uuid_v7(attrs, :creator_operation_id),
         {:ok, session_id} <- check_identifier(attrs, :session_id),
         {:ok, run_id} <- check_identifier(attrs, :run_id),
         {:ok, owner_kind} <- check_enum(attrs, :owner_kind, @owner_kinds),
         {:ok, owner_id} <- check_identifier(attrs, :owner_id),
         {:ok, producer_kind} <- check_enum(attrs, :producer_kind, @producer_kinds),
         {:ok, producer_id} <- check_identifier(attrs, :producer_id),
         {:ok, kind} <- check_enum(attrs, :kind, @kinds),
         {:ok, media_type} <- check_bounded_text(attrs, :media_type, @max_media_type_bytes),
         {:ok, encoding} <- check_enum(attrs, :encoding, @encodings),
         {:ok, content_digest} <- check_content_digest(attrs),
         {:ok, byte_size} <- check_byte_size(attrs),
         {:ok, content_location} <- check_relative_location(attrs),
         {:ok, repository_state_digest} <-
           check_optional_non_empty(attrs, :repository_state_digest),
         {:ok, host_profile_digest} <- check_optional_non_empty(attrs, :host_profile_digest),
         {:ok, trust} <- check_enum(attrs, :trust, @trusts),
         {:ok, sensitivity} <- check_enum(attrs, :sensitivity, @sensitivities),
         {:ok, retention_class} <- check_enum(attrs, :retention_class, @retention_classes),
         {:ok, completeness} <- check_enum(attrs, :completeness, @completeness_values),
         {:ok, recorded_at} <- check_bounded_text(attrs, :recorded_at, 64),
         {:ok, idempotency_key} <- check_identifier(attrs, :idempotency_key) do
      {:ok,
       %__MODULE__{
         artifact_id: artifact_id,
         session_id: session_id,
         run_id: run_id,
         creator_operation_id: creator_operation_id,
         owner_kind: owner_kind,
         owner_id: owner_id,
         producer_kind: producer_kind,
         producer_id: producer_id,
         kind: kind,
         media_type: media_type,
         encoding: encoding,
         content_digest: content_digest,
         byte_size: byte_size,
         content_location: content_location,
         repository_state_digest: repository_state_digest,
         host_profile_digest: host_profile_digest,
         trust: trust,
         sensitivity: sensitivity,
         retention_class: retention_class,
         completeness: completeness,
         recorded_at: recorded_at,
         schema: @schema,
         idempotency_key: idempotency_key,
         request_digest: nil
       }}
    end
  end

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

  defp check_optional_uuid_v7(attrs, key) do
    case Map.get(attrs, key) do
      nil ->
        {:ok, nil}

      value ->
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
  end

  defp check_identifier(attrs, key) do
    value = Map.fetch!(attrs, key)

    case value do
      v when is_binary(v) ->
        if byte_size(v) == 0 do
          {:error,
           Error.new(
             :precondition,
             :empty_identifier,
             "identifier must not be empty",
             %{field: key}
           )}
        else
          case ensure_no_nul_or_control(v) do
            :ok ->
              if byte_size(v) > @max_identifier_bytes do
                {:error, limit_error(key, @max_identifier_bytes, byte_size(v))}
              else
                {:ok, v}
              end

            {:error, _} = err ->
              err
          end
        end

      _ ->
        {:error,
         Error.new(:precondition, :wrong_type, "identifier must be a binary", %{field: key})}
    end
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

          true ->
            case ensure_no_nul_or_control(v) do
              :ok -> {:ok, v}
              {:error, _} = err -> err
            end
        end

      _ ->
        {:error,
         Error.new(:precondition, :wrong_type, "text field must be a binary", %{field: key})}
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

  defp check_content_digest(attrs) do
    value = Map.fetch!(attrs, :content_digest)

    if is_binary(value) and byte_size(value) == 71 and
         String.starts_with?(value, "sha256:") and
         Regex.match?(~r/^sha256:[0-9a-f]{64}$/, value) do
      {:ok, value}
    else
      {:error,
       Error.new(
         :precondition,
         :malformed_content_digest,
         "content_digest must be sha256: followed by 64 lowercase hex characters",
         %{value: nil}
       )}
    end
  end

  defp check_byte_size(attrs) do
    value = Map.fetch!(attrs, :byte_size)

    if is_integer(value) and value >= 0 and value <= @max_byte_size do
      {:ok, value}
    else
      {:error,
       Error.new(
         :precondition,
         :limit_exceeded,
         "byte_size is outside the accepted bounds",
         %{field: :byte_size, max: @max_byte_size, value: nil}
       )}
    end
  end

  defp check_relative_location(attrs) do
    value = Map.fetch!(attrs, :content_location)

    cond do
      not is_binary(value) ->
        {:error,
         Error.new(
           :precondition,
           :wrong_type,
           "content_location must be a binary",
           %{field: :content_location}
         )}

      byte_size(value) == 0 ->
        {:error,
         Error.new(
           :precondition,
           :empty_text,
           "content_location must not be empty",
           %{field: :content_location}
         )}

      byte_size(value) > @max_relative_location_bytes ->
        {:error, limit_error(:content_location, @max_relative_location_bytes, byte_size(value))}

      String.starts_with?(value, "/") ->
        {:error,
         Error.new(
           :precondition,
           :absolute_path,
           "content_location must be relative",
           %{field: :content_location}
         )}

      String.contains?(value, "..") ->
        {:error,
         Error.new(
           :precondition,
           :path_escape,
           "content_location must not contain '..' segments",
           %{field: :content_location}
         )}

      true ->
        case ensure_no_nul_or_control(value) do
          :ok -> {:ok, value}
          {:error, _} = err -> err
        end
    end
  end

  defp check_optional_non_empty(attrs, key) do
    case Map.get(attrs, key) do
      nil ->
        {:ok, nil}

      value when is_binary(value) ->
        cond do
          byte_size(value) == 0 ->
            {:error,
             Error.new(
               :precondition,
               :empty_text,
               "field must not be empty when present",
               %{field: key}
             )}

          true ->
            {:ok, value}
        end

      _ ->
        {:error,
         Error.new(:precondition, :wrong_type, "field must be a binary or nil", %{field: key})}
    end
  end

  defp ensure_no_nul_or_control(value) when is_binary(value) do
    if value |> :binary.bin_to_list() |> Enum.any?(&disallowed_control?/1) do
      {:error,
       Error.new(
         :precondition,
         :disallowed_control_byte,
         "value contains a NUL or disallowed control byte",
         %{}
       )}
    else
      :ok
    end
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
