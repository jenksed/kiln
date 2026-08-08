defmodule Kiln.Artifact.Store do
  @moduledoc """
  Content-addressed Artifact persistence for kiln-state/v1.

  `put/2` records one Artifact row. The `artifact_id` is the lowercase
  hex SHA-256 digest over the canonical content bytes, prefixed with the
  `sha256:` scheme, and is computed deterministically by
  `Kiln.Artifact.Canonical`. The same input bytes always produce the
  same `artifact_id`; a different byte produces a different
  `artifact_id`. A re-insert of the same content yields an
  SQLite UNIQUE-constraint rejection (the protected `replay_attack`
  fixture relies on this property).

  Bounded vocabulary columns (content_kind, encoding, retention_class,
  producer_kind) are validated here. SQLite is not a vocabulary
  enforcement layer; the Store is. Any rejection returns
  `{:error, %Kiln.Store.Error{class: :artifact}}` and writes no row.

  No process, registry, or external capability is reachable from this
  module. No nested transaction or savepoint machinery is used.
  """

  alias Kiln.Artifact.{Canonical, Error}
  alias Kiln.Store.Connection

  @content_kinds [:text, :json, :binary, :unstructured]
  @encodings [:utf_8, :utf_8_bom]
  @retention_classes [:transient, :durable]
  @producer_kinds [:command, :provider, :pack, :patch, :script, :internal]
  @artifact_schema "kiln.artifact/v1"

  @type content_kind :: :text | :json | :binary | :unstructured
  @type encoding :: :utf_8 | :utf_8_bom
  @type retention_class :: :transient | :durable
  @type producer_kind :: :command | :provider | :pack | :patch | :script | :internal

  @type put_attrs :: %{
          required(:byte_size) => non_neg_integer(),
          required(:content_kind) => content_kind(),
          required(:encoding) => encoding(),
          required(:media_type) => String.t(),
          required(:retention_class) => retention_class(),
          required(:producer_kind) => producer_kind(),
          required(:producer_id) => String.t(),
          required(:source_digest) => String.t(),
          optional(:recorded_at) => String.t()
        }

  @doc """
  Insert one Artifact row using `attrs` for metadata and `content` as the
  content bytes.

  Returns `{:ok, %{"artifact_id" => sha256:..., "byte_size" => n}}` on
  success. Returns `{:error, %Error{class: :artifact}}` for any bounded
  vocabulary rejection or content/digest mismatch.

  The transaction is `IMMEDIATE` (Kiln-owned) so a concurrent reader
  cannot observe a partial state.
  """
  @spec put(Connection.conn(), put_attrs(), iodata() | binary()) ::
          {:ok, %{artifact_id: String.t(), byte_size: non_neg_integer()}}
          | {:error, Error.t()}
  def put(conn, attrs, content) when is_map(attrs) do
    content_bin = IO.iodata_to_binary(content)

    with {:ok, normalized} <- validate_attrs(attrs, byte_size(content_bin)),
         {:ok, artifact_id} <- compute_id(content_bin) do
      try do
        case Connection.transaction(conn, fn tx ->
               Connection.query!(
                 tx,
                 """
                 INSERT INTO artifacts (
                   artifact_id, byte_size, content_kind, encoding, media_type,
                   retention_class, producer_kind, producer_id, recorded_at,
                   source_digest, schema, content
                 ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12)
                 """,
                 [
                   artifact_id,
                   normalized.byte_size,
                   Atom.to_string(normalized.content_kind),
                   Atom.to_string(normalized.encoding),
                   normalized.media_type,
                   Atom.to_string(normalized.retention_class),
                   Atom.to_string(normalized.producer_kind),
                   normalized.producer_id,
                   normalized.recorded_at,
                   normalized.source_digest,
                   @artifact_schema,
                   content_bin
                 ]
               )
             end) do
          {:ok, _} ->
            {:ok, %{artifact_id: artifact_id, byte_size: normalized.byte_size}}

          {:error, reason} ->
            {:error,
             Kiln.Store.Error.new(
               :artifact,
               :persistence_failed,
               "artifact insert failed",
               %{artifact_id: artifact_id, reason: inspect(reason)}
             )}
        end
      rescue
        exception ->
          {:error,
           Kiln.Store.Error.new(
             :artifact,
             :persistence_failed,
             "artifact insert raised",
             %{artifact_id: artifact_id, reason: Exception.message(exception)}
           )}
      end
    end
  end

  defp validate_attrs(attrs, computed_size) do
    with {:ok, content_kind} <-
           validate_member(:content_kind, Map.get(attrs, :content_kind), @content_kinds),
         {:ok, encoding} <- validate_member(:encoding, Map.get(attrs, :encoding), @encodings),
         {:ok, retention_class} <-
           validate_member(:retention_class, Map.get(attrs, :retention_class), @retention_classes),
         {:ok, producer_kind} <-
           validate_member(:producer_kind, Map.get(attrs, :producer_kind), @producer_kinds),
         {:ok, media_type} <- validate_nonempty(:media_type, Map.get(attrs, :media_type)),
         {:ok, producer_id} <- validate_nonempty(:producer_id, Map.get(attrs, :producer_id)),
         {:ok, source_digest} <- validate_digest_format(Map.get(attrs, :source_digest)),
         {:ok, byte_size} <- validate_byte_size(Map.get(attrs, :byte_size), computed_size) do
      recorded_at = Map.get(attrs, :recorded_at) || utc_now()

      {:ok,
       %{
         byte_size: byte_size,
         content_kind: content_kind,
         encoding: encoding,
         retention_class: retention_class,
         producer_kind: producer_kind,
         media_type: media_type,
         producer_id: producer_id,
         source_digest: source_digest,
         recorded_at: recorded_at
       }}
    end
  end

  defp validate_byte_size(declared, computed_size) do
    cond do
      not is_integer(declared) or declared < 0 ->
        {:error, Error.invalid_field(:byte_size, declared, "must be a non-negative integer")}

      declared != computed_size ->
        {:error, Error.content_mismatch("uncomputed", declared, computed_size)}

      true ->
        {:ok, declared}
    end
  end

  defp validate_member(field, value, allowed) do
    if value in allowed do
      {:ok, value}
    else
      {:error, Error.invalid_field(field, value, "must be one of #{inspect(allowed)}")}
    end
  end

  defp validate_nonempty(field, value) do
    if is_binary(value) and byte_size(value) > 0 do
      {:ok, value}
    else
      {:error, Error.invalid_field(field, value, "must be a non-empty string")}
    end
  end

  defp validate_digest_format("sha256:" <> hex) when byte_size(hex) == 64 do
    if hex =~ ~r/^[0-9a-f]{64}$/ do
      {:ok, "sha256:" <> hex}
    else
      {:error, Error.invalid_digest_format("sha256:" <> hex)}
    end
  end

  defp validate_digest_format(digest) do
    {:error, Error.invalid_digest_format(digest)}
  end

  defp compute_id(content_bin) do
    {:ok, Canonical.artifact_id(content_bin)}
  end

  defp utc_now do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end
end
