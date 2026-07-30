defmodule Kiln.CLI.TextRenderer do
  @moduledoc """
  Deterministic text rendering of a `Kiln.CLI.Result`.

  The text view and the JSON view describe the same authoritative state. The
  renderer is a pure function over its input plus the command name. It never
  reads the database, the Repository, the provider, or the filesystem, and it
  never infers new facts (P1-S01-T04-R12, R13).
  """

  alias Kiln.CLI.Result

  @doc "Render `result` as plain text suitable for a terminal or log."
  @spec render(Result.t()) :: String.t()
  def render(%Result{} = result) do
    sections = [
      status_line(result),
      subject_line(result),
      data_section(result),
      warnings_section(result),
      errors_section(result),
      next_actions_section(result),
      tail_line(result)
    ]

    joined =
      sections
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n")

    joined <> "\n"
  end

  defp status_line(%Result{status: status, exit_code: code}) do
    "status: #{status} (exit #{code})"
  end

  defp subject_line(%Result{session_revision: nil}), do: ""

  defp subject_line(%Result{session_revision: revision, journal_digest: digest}) do
    "revision: #{revision}" <>
      if(digest, do: "\nprojection_digest: #{digest}", else: "")
  end

  defp data_section(%Result{data: nil}), do: ""

  defp data_section(%Result{command: command, data: data}) when not is_nil(data) do
    case command do
      "start" -> render_start(data)
      "status" -> render_status(data)
      "inspect" -> render_inspect(data)
      "cancel" -> render_cancel(data)
      "resume" -> render_resume(data)
      "help" -> render_help(data)
      "version" -> render_version(data)
      _ -> ""
    end
  end

  defp render_start(data) when is_map(data) do
    lines = [
      "session: #{data.session_id}",
      "task: #{data.task_id}",
      "root_run: #{data.root_run_id}",
      "objective: #{data.objective}"
    ]

    "started:\n" <> Enum.map_join(lines, "\n", &("  " <> &1))
  end

  defp render_status(data) when is_map(data) do
    lines = [
      "session: #{data.session_id} (#{data.session_state})",
      "task: #{data.task_id} (#{data.task_state})",
      "root_run: #{data.root_run_id} (#{data.run_state})",
      "workflow_step: #{data.workflow_step}"
    ]

    extras =
      []
      |> maybe_append_line("pending_decision", data[:pending_decision])
      |> maybe_append_line("operation", data[:operation])
      |> maybe_append_line("cache_status", data[:cache_status])
      |> maybe_append_line("orphaned", data[:orphaned])
      |> maybe_append_line("journal_head", data[:journal_head])

    "status:\n" <> Enum.map_join(lines ++ extras, "\n", &("  " <> &1))
  end

  defp render_inspect(data) when is_map(data) do
    lines = [
      "session_id: #{data.session_id}",
      "session_state: #{data.session_state}",
      "task_id: #{data.task_id}",
      "task_state: #{data.task_state}",
      "root_run_id: #{data.root_run_id}",
      "run_state: #{data.run_state}",
      "workflow_step: #{data.workflow_step}",
      "objective_revision: #{data.objective_revision}",
      "criteria_revision: #{data.criteria_revision}",
      "objective: #{data.objective}",
      "criteria: #{Enum.join(data.criteria, "; ")}",
      "constraints: #{Enum.join(data.constraints, "; ")}",
      "exclusions: #{Enum.join(data.exclusions, "; ")}"
    ]

    extras =
      []
      |> maybe_append_line("pending_decision", data[:pending_decision])
      |> maybe_append_line("operation", data[:operation])
      |> maybe_append_line("unknowns", data[:unknowns])
      |> maybe_append_line("project_observation_id", data[:project_observation_id])
      |> maybe_append_line("journal_head_digest", data[:journal_head_digest])
      |> maybe_append_line("projection_digest", data[:projection_digest])

    "inspect:\n" <> Enum.map_join(lines ++ extras, "\n", &("  " <> &1))
  end

  defp render_cancel(data) when is_map(data) do
    lines = [
      "session: #{data.session_id}",
      "task: #{data.task_id}",
      "root_run: #{data.root_run_id}",
      "previous_run_state: #{data.previous_run_state}",
      "run_state: #{data.run_state}"
    ]

    "canceled:\n" <> Enum.map_join(lines, "\n", &("  " <> &1))
  end

  defp render_resume(data) when is_map(data) do
    state_lines = [
      "session: #{data.session_id} (#{data.session_state})",
      "task: #{data.task_id} (#{data.task_state})",
      "root_run: #{data.root_run_id} (#{data.run_state})",
      "workflow_step: #{data.workflow_step}"
    ]

    state_section = "current:\n" <> Enum.map_join(state_lines, "\n", &("  " <> &1))

    actions =
      Enum.map(data.next_actions, fn action ->
        "  - #{action.action}: #{action.description}"
      end)

    extras_section =
      if actions == [] do
        ""
      else
        "suggested next actions:\n" <> Enum.join(actions, "\n")
      end

    Enum.reject([state_section, extras_section], &(&1 == "")) |> Enum.join("\n")
  end

  defp render_help(data) when is_map(data) do
    usage_line = "usage: #{data.usage}"

    command_lines =
      Enum.map(data.commands, fn c ->
        "  - #{c.command}: #{c.description}"
      end)

    global_lines =
      Enum.map(data.global_options, fn o ->
        "  - #{o.flag}: #{o.description}"
      end)

    note_lines = Enum.map(data.notes, fn note -> "  - " <> note end)

    sections =
      [
        usage_line,
        "commands:\n" <> Enum.join(command_lines, "\n"),
        "global options:\n" <> Enum.join(global_lines, "\n"),
        "notes:\n" <> Enum.join(note_lines, "\n")
      ]
      |> Enum.reject(&(&1 == ""))

    "help:\n" <> Enum.map_join(sections, "\n\n", &("  " <> &1))
  end

  defp render_version(data) when is_map(data) do
    "version: #{data.version}\nschema: #{data.schema}"
  end

  defp warnings_section(%Result{warnings: []}), do: ""

  defp warnings_section(%Result{warnings: warnings}) do
    items = Enum.map(warnings, fn w -> "  - [#{w.code}] #{w.message}" end)
    "warnings:\n" <> Enum.join(items, "\n")
  end

  defp errors_section(%Result{errors: []}), do: ""

  defp errors_section(%Result{errors: errors}) do
    items =
      Enum.map(errors, fn e ->
        details =
          case e.details do
            %{} when map_size(e.details) == 0 -> ""
            details -> " (" <> render_details(details) <> ")"
          end

        "  - [#{e.code}/#{e.class}] #{e.message}" <> details
      end)

    "errors:\n" <> Enum.join(items, "\n")
  end

  defp render_details(details) do
    details
    |> Enum.sort_by(fn {k, _} -> to_string(k) end)
    |> Enum.map_join(", ", fn {k, v} -> "#{k}=#{inspect(v)}" end)
  end

  defp next_actions_section(%Result{next_actions: []}), do: ""

  defp next_actions_section(%Result{next_actions: next_actions}) do
    items =
      Enum.map(next_actions, fn next_action ->
        "  - #{next_action.action}: #{next_action.description}"
      end)

    "next actions:\n" <> Enum.join(items, "\n")
  end

  defp tail_line(%Result{emitted_at: nil}), do: ""

  defp tail_line(%Result{emitted_at: at}) do
    "emitted_at: #{at}"
  end

  defp maybe_append_line(lines, _key, nil), do: lines
  defp maybe_append_line(lines, _key, []), do: lines

  defp maybe_append_line(lines, key, value) when is_binary(value) do
    lines ++ ["#{key}: #{value}"]
  end

  defp maybe_append_line(lines, key, value) do
    lines ++ ["#{key}: #{inspect(value)}"]
  end
end
