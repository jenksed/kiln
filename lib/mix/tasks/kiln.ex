defmodule Mix.Tasks.Kiln do
  @moduledoc """
  The source-development `mix kiln` entry point.

  This task is the smallest foreground CLI over the implemented P1-S01 domain.
  It accepts the documented global flags (`--format`, `--kiln-home`, `--help`,
  `--version`) and the P1-S01 commands (`start`, `status`, `inspect`, `cancel`,
  `resume`). It is non-authoritative presentation: every command routes through
  `Kiln.CLI.run/1` and never touches the Repository, provider, Context, Patch,
  Command, completion, Receipt, Child, or TUI behavior (P1-S01-T04-R12, R13,
  R14).

  The packaged `kiln` Mix release is not yet shipped. This is a development
  entry point and identifies itself as such.
  """

  @shortdoc "Foreground P1-S01 CLI entry point (development)"

  use Mix.Task

  def run(argv) do
    case Kiln.CLI.Request.parse(argv) do
      {:ok, request} ->
        {result, exit_code} = Kiln.CLI.run(request)
        emit(request, result)
        exit({:shutdown, exit_code})

      {:error, error} ->
        request = %Kiln.CLI.Request{command: nil, format: requested_format(argv)}

        result =
          Kiln.CLI.Result.error("kiln", :denied,
            exit_code: 2,
            errors: [error]
          )

        emit(request, result)
        exit({:shutdown, result.exit_code})
    end
  end

  defp emit(request, result) do
    output = render(request, result)
    Mix.shell().info(String.trim_trailing(output, "\n"))
  end

  defp render(%Kiln.CLI.Request{format: :json}, %Kiln.CLI.Result{} = result),
    do: Kiln.CLI.JsonRenderer.render(result)

  defp render(%Kiln.CLI.Request{}, %Kiln.CLI.Result{} = result),
    do: Kiln.CLI.TextRenderer.render(result)

  defp requested_format(argv) do
    if "--format=json" in argv or
         Enum.any?(Enum.chunk_every(argv, 2, 1, :discard), &(&1 == ["--format", "json"])) do
      :json
    else
      :text
    end
  end
end
