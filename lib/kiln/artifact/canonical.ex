defmodule Kiln.Artifact.Canonical do
  @moduledoc """
  Canonical-byte identity for content-addressed Artifacts.

  The artifact identity is the lowercase hex SHA-256 digest of the
  Artifact's content bytes, prefixed with the `sha256:` scheme. The same
  bytes always produce the same digest; different bytes always produce
  a different digest. No other Artifact field participates in the digest
  computation; producer identification, retention class, and recorded_at
  are metadata that the row records but do not influence identity.

  This module is intentionally minimal. It does not validate vocabulary
  (that's `Kiln.Artifact.Store`); it only computes the content digest
  and the row's `sha256:` digest string.
  """

  @doc "Lowercase hex SHA-256 digest over the content bytes."
  @spec content_digest(iodata() | binary()) :: String.t()
  def content_digest(bytes) do
    :sha256
    |> :crypto.hash(bytes)
    |> Base.encode16(case: :lower)
  end

  @doc "Full artifact_id: lowercase hex SHA-256 with the `sha256:` scheme prefix."
  @spec artifact_id(iodata() | binary()) :: String.t()
  def artifact_id(bytes), do: "sha256:" <> content_digest(bytes)
end
