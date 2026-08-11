defmodule Kiln.Artifact.PutRequest do
  @moduledoc """
  The exact typed request accepted by `Kiln.Artifact.Store.put/2`.

  A PutRequest separates the content bytes from the immutable Artifact
  metadata. The same logical Artifact record with different bytes produces
  different content digests and therefore different content-addressed blobs;
  the same bytes with different provenance produce different `artifact_id`s
  that may share a blob (P1-S02-T01-R02).

  Validation runs entirely before any filesystem staging or SQLite transaction
  so that overflow, malformed identifiers, NUL/disallowed-control bytes, and
  invalid vocabularies return `precondition` errors without leaving side
  effects. Application validation is the source of truth; SQLite CHECK
  constraints enforce the same byte and shape bounds as a defense-in-depth
  layer at the direct-SQL boundary (P1-S02-T01-R08).
  """

  alias Kiln.Store.Error

  @enforce_keys [:artifact_id, :idempotency_key, :recorded_at, :bytes, :metadata]
  defstruct [:artifact_id, :idempotency_key, :recorded_at, :bytes, :metadata]

  @type t :: %__MODULE__{
          artifact_id: String.t(),
          idempotency_key: String.t(),
          recorded_at: String.t(),
          bytes: binary(),
          metadata: map()
        }

  @doc """
  Construct and validate a PutRequest.

  `attrs` is a map with keys `:artifact_id`, `:idempotency_key`, `:recorded_at`,
  `:bytes`, and `:metadata`. The metadata map is forwarded to
  `Kiln.Artifact.new/1` after the request envelope is validated.

  Returns `{:ok, request}` or a classified `Kiln.Store.Error`.
  """
  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attrs) when is_map(attrs) do
    required = [:artifact_id, :idempotency_key, :recorded_at, :bytes, :metadata]

    case Enum.find(required, fn key -> not Map.has_key?(attrs, key) end) do
      nil ->
        build(attrs)

      key ->
        {:error,
         Error.new(
           :precondition,
           :missing_field,
           "put_request is missing a required field",
           %{field: key}
         )}
    end
  end

  defp build(attrs) do
    artifact_id = Map.fetch!(attrs, :artifact_id)
    idempotency_key = Map.fetch!(attrs, :idempotency_key)
    recorded_at = Map.fetch!(attrs, :recorded_at)
    bytes = Map.fetch!(attrs, :bytes)
    metadata = Map.fetch!(attrs, :metadata)

    envelope = %{
      artifact_id: artifact_id,
      idempotency_key: idempotency_key,
      recorded_at: recorded_at,
      bytes: bytes
    }

    with {:ok, artifact_id} <- check_uuid_v7(artifact_id),
         {:ok, idempotency_key} <- check_idempotency_key(idempotency_key),
         {:ok, recorded_at} <- check_recorded_at(recorded_at),
         {:ok, bytes} <- check_bytes(bytes),
         :ok <- check_canonical_request_size(envelope, metadata) do
      {:ok,
       %__MODULE__{
         artifact_id: artifact_id,
         idempotency_key: idempotency_key,
         recorded_at: recorded_at,
         bytes: bytes,
         metadata: metadata
       }}
    end
  end

  defp check_uuid_v7(value) do
    if Kiln.Artifact.uuid_v7?(value) do
      {:ok, value}
    else
      {:error,
       Error.new(
         :precondition,
         :malformed_uuid_v7,
         "artifact_id must be a UUIDv7 identifier",
         %{value: nil}
       )}
    end
  end

  defp check_idempotency_key(value) when is_binary(value) do
    cond do
      byte_size(value) == 0 ->
        {:error,
         Error.new(
           :precondition,
           :empty_idempotency_key,
           "idempotency_key must not be empty",
           %{}
         )}

      byte_size(value) > 256 ->
        {:error,
         Error.new(
           :precondition,
           :limit_exceeded,
           "idempotency_key exceeds the accepted bound",
           %{max: 256, actual: byte_size(value)}
         )}

      has_disallowed_control?(value) ->
        {:error,
         Error.new(
           :precondition,
           :disallowed_control_byte,
           "idempotency_key contains a NUL or disallowed control byte",
           %{}
         )}

      true ->
        {:ok, value}
    end
  end

  defp check_idempotency_key(_),
    do: {:error, Error.new(:precondition, :wrong_type, "idempotency_key must be a binary", %{})}

  defp check_recorded_at(value) when is_binary(value) do
    cond do
      byte_size(value) == 0 ->
        {:error,
         Error.new(
           :precondition,
           :empty_recorded_at,
           "recorded_at must not be empty",
           %{}
         )}

      byte_size(value) > 64 ->
        {:error,
         Error.new(
           :precondition,
           :limit_exceeded,
           "recorded_at exceeds the accepted bound",
           %{max: 64, actual: byte_size(value)}
         )}

      has_disallowed_control?(value) ->
        {:error,
         Error.new(
           :precondition,
           :disallowed_control_byte,
           "recorded_at contains a NUL or disallowed control byte",
           %{}
         )}

      true ->
        {:ok, value}
    end
  end

  defp check_recorded_at(_),
    do: {:error, Error.new(:precondition, :wrong_type, "recorded_at must be a binary", %{})}

  defp check_bytes(value) when is_binary(value) do
    if byte_size(value) > Kiln.Artifact.max_byte_size() do
      {:error,
       Error.new(
         :precondition,
         :limit_exceeded,
         "content bytes exceed the accepted bound",
         %{max: Kiln.Artifact.max_byte_size(), actual: byte_size(value)}
       )}
    else
      {:ok, value}
    end
  end

  defp check_bytes(_),
    do: {:error, Error.new(:precondition, :wrong_type, "bytes must be a binary", %{})}

  defp check_canonical_request_size(envelope, metadata) do
    canonical = Kiln.Artifact.persistent_request_map(envelope, metadata)
    encoded = Kiln.Store.Canonical.encode(canonical)

    if byte_size(encoded) > Kiln.Artifact.max_canonical_request() do
      {:error,
       Error.new(
         :precondition,
         :limit_exceeded,
         "canonical artifact request exceeds the accepted bound",
         %{max: Kiln.Artifact.max_canonical_request(), actual: byte_size(encoded)}
       )}
    else
      :ok
    end
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
