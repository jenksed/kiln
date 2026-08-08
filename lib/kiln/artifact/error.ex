defmodule Kiln.Artifact.Error do
  @moduledoc """
  Thin shim over `Kiln.Store.Error` with the `:artifact` class.

  Artifact persistence failures are owned by the Store layer; this module
  only constructs structured `Kiln.Store.Error{}` values for the bounded
  vocabulary rejections and digest-shape checks performed by
  `Kiln.Artifact.Store.put/2`.

  No process, registry, or capability surface is introduced.
  """

  alias Kiln.Store.Error

  @type t :: %Error{class: :artifact}

  @spec invalid_field(atom(), term(), String.t()) :: t()
  def invalid_field(field, value, reason) do
    Error.new(:artifact, :invalid_field, "artifact field #{inspect(field)} rejected", %{
      field: field,
      value: value,
      reason: reason
    })
  end

  @spec invalid_digest_format(String.t()) :: t()
  def invalid_digest_format(digest) do
    Error.new(
      :artifact,
      :invalid_digest_format,
      "digest must be sha256:<64 lowercase hex chars>",
      %{digest: digest}
    )
  end

  @spec content_mismatch(String.t(), non_neg_integer(), non_neg_integer()) :: t()
  def content_mismatch(digest, expected_size, actual_size) do
    Error.new(
      :artifact,
      :content_mismatch,
      "artifact content size does not match declared byte_size",
      %{digest: digest, expected_size: expected_size, actual_size: actual_size}
    )
  end
end
