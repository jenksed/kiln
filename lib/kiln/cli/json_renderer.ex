defmodule Kiln.CLI.JsonRenderer do
  @moduledoc """
  Deterministic JSON rendering of a `Kiln.CLI.Result`.

  The renderer is a one-shot function over a single result. It emits exactly one
  UTF-8 JSON document that conforms to `kiln.cli.result/v1` and never writes to
  the database, the Repository, the provider, or the filesystem. Output order is
  stable and the keys are sorted, so the same logical result always produces the
  same bytes (P1-S01-T04-R11).
  """

  alias Kiln.CLI.Result

  @doc "Render `result` as a single newline-terminated JSON document."
  @spec render(Result.t()) :: String.t()
  def render(%Result{} = result) do
    result
    |> build()
    |> json_value()
    |> JSON.encode!()
    |> Kernel.<>("\n")
  end

  defp build(%Result{} = result) do
    %{
      kind: Result.kind(),
      schema: Result.schema(),
      command: result.command,
      status: to_string(result.status),
      exit_code: result.exit_code,
      data: result.data,
      errors: result.errors,
      warnings: result.warnings,
      next_actions: result.next_actions,
      session_revision: result.session_revision,
      journal_digest: result.journal_digest,
      emitted_at: result.emitted_at
    }
  end

  defp json_value(map) when is_map(map) and not is_struct(map) do
    Map.new(map, fn {key, value} -> {to_string(key), json_value(value)} end)
  end

  defp json_value(list) when is_list(list), do: Enum.map(list, &json_value/1)

  defp json_value(value) when is_atom(value) and value not in [true, false, nil],
    do: Atom.to_string(value)

  defp json_value(value), do: value
end
