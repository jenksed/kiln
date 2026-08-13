defmodule Kiln.WorkEnvelopeLoader do
  @moduledoc """
  Read a Work Envelope v0 payload from disk.

  Accepts JSON inputs (`.json`) only. The CLI's `--work-envelope`
  flag accepts a path; this loader reads it and returns the parsed map
  the supervisor and `Kiln.WorkEnvelope.new/1` accept.

  The loader never executes code, never reaches into the Store, and
  performs no filesystem mutation.
  """

  alias Kiln.Store.Error

  @doc """
  Load a Work Envelope payload from `path`.

  Returns `{:ok, attrs}` where `attrs` is the map shape, or
  `{:error, error}`.
  """
  @spec load(Path.t()) :: {:ok, map()} | {:error, Error.t()}
  def load(path) when is_binary(path) do
    case File.read(path) do
      {:ok, contents} ->
        parse(contents)

      {:error, reason} ->
        {:error,
         Error.new(
           :precondition,
           :cannot_read_file,
           "work envelope file could not be read",
           %{path: path, reason: inspect(reason)}
         )}
    end
  end

  defp parse(contents) do
    case JSON.decode(contents) do
      {:ok, value} when is_map(value) ->
        {:ok, value}

      {:ok, _other} ->
        {:error,
         Error.new(
           :precondition,
           :invalid_payload,
           "work envelope payload must be a JSON object at the top level",
           %{}
         )}

      {:error, reason} ->
        {:error,
         Error.new(
           :precondition,
           :invalid_payload,
           "work envelope JSON could not be decoded",
           %{reason: inspect(reason)}
         )}
    end
  end
end
