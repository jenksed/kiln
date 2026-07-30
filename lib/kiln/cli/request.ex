defmodule Kiln.CLI.Request do
  @moduledoc """
  Bounded parser for the foundation CLI request.

  This parser handles only the P1-S01 surface: global flags
  (`--format`, `--kiln-home`, `--help`, `--version`), and the commands
  `start`, `status`, `inspect`, `cancel`, and `resume`. Anything else
  resolves to a structured usage error that the renderer formats; the CLI
  never falls back to a framework or silently treats it as success.

  Parsing is total: a malformed flag, an unknown command, or a missing
  required option returns `{:error, error}` with a stable
  `USAGE_ERROR` code. The CLI is non-authoritative, so this module never
  touches the database, provider, Repository, or model.
  """

  alias Kiln.CLI.Result

  @supported_commands [:start, :status, :inspect, :cancel, :resume]
  @command_lookup Map.new(@supported_commands, &{Atom.to_string(&1), &1})

  @enforce_keys [:command]
  defstruct command: nil,
            format: nil,
            kiln_home: nil,
            show_help: false,
            show_version: false,
            options: %{},
            positional: []

  @type format :: :text | :json

  @type t :: %__MODULE__{
          command: atom() | nil,
          format: format(),
          kiln_home: String.t() | nil,
          show_help: boolean(),
          show_version: boolean(),
          options: map(),
          positional: [String.t()]
        }

  @doc "Parse argv into a request or a structured usage error."
  @spec parse([String.t()]) :: {:ok, t()} | {:error, Result.error()}
  def parse(argv) when is_list(argv) do
    case tokenize(argv) do
      {:ok, tokens} -> decode(tokens)
      {:error, _} = error -> error
    end
  end

  # -- tokenization --

  @value_flags ~w(--format --kiln-home --repo --objective --criterion --constraint --exclude --reason)
  @repeating_flags ~w(criterion constraint exclude)
  @command_flags %{
    start: ~w(repo objective criterion constraint exclude),
    status: [],
    inspect: [],
    cancel: ~w(reason),
    resume: []
  }

  defp tokenize(argv) do
    Enum.reduce_while(argv, {:ok, []}, fn token, {:ok, acc} ->
      cond do
        String.starts_with?(token, "--") ->
          {:cont, {:ok, parse_long(token, acc)}}

        String.starts_with?(token, "-") and token != "-" ->
          {:halt, usage("unknown short flag: #{token}")}

        true ->
          {:cont, {:ok, acc ++ [{:positional, token}]}}
      end
    end)
  end

  defp parse_long(token, acc) do
    case String.split(token, "=", parts: 2) do
      [flag] when flag in @value_flags ->
        acc ++ [{:flag, flag, :needs_value}]

      [flag] ->
        acc ++ [{:flag, flag, nil}]

      [flag, value] ->
        acc ++ [{:flag, flag, value}]
    end
  end

  # -- decode --

  defp decode(tokens) do
    tokens = consume_value_flags(tokens, [])

    {globals, rest} =
      Enum.split_with(tokens, fn
        {:flag, "--format", _} -> true
        {:flag, "--kiln-home", _} -> true
        {:flag, "--help", _} -> true
        {:flag, "--version", _} -> true
        _ -> false
      end)

    with {:ok, %__MODULE__{} = global_opts} <- decode_globals(globals, base_request()) do
      cond do
        global_opts.show_help or global_opts.show_version ->
          {:ok, global_opts}

        true ->
          decode_command_into(global_opts, rest)
      end
    end
  end

  # When a flag requires a value but was written without `=`, the next
  # positional token is consumed as that flag's value.
  defp consume_value_flags([], acc), do: Enum.reverse(acc)

  defp consume_value_flags([{:flag, flag, :needs_value} | [next | rest]], acc)
       when is_tuple(next) do
    case next do
      {:positional, value} ->
        consume_value_flags(rest, [{:flag, flag, value} | acc])

      _ ->
        consume_value_flags([next | rest], [{:flag, flag, nil} | acc])
    end
  end

  defp consume_value_flags([token | rest], acc) do
    consume_value_flags(rest, [token | acc])
  end

  defp decode_command_into(%__MODULE__{} = global_opts, rest) do
    with {:ok, command, body} <- decode_command(rest),
         :ok <- validate_command_body(command, body),
         {:ok, options} <- parse_options(command, body) do
      {:ok, %__MODULE__{global_opts | command: command, options: options, positional: []}}
    end
  end

  defp decode_globals([], request), do: {:ok, %{request | command: nil}}

  defp decode_globals([{:flag, flag, value} | rest], request) do
    case decode_global(flag, value, request) do
      {:ok, next} -> decode_globals(rest, next)
      {:error, _} = error -> error
    end
  end

  defp decode_global("--format", value, request) do
    case parse_format(value) do
      {:ok, format} -> {:ok, %{request | format: format, command: nil}}
      :error -> usage("--format must be text or json")
    end
  end

  defp decode_global("--kiln-home", value, request) do
    case validate_kiln_home(value) do
      {:ok, path} -> {:ok, %{request | kiln_home: path, command: nil}}
      {:error, _} = error -> error
    end
  end

  defp decode_global("--help", nil, request),
    do: {:ok, %{request | show_help: true, command: nil}}

  defp decode_global("--version", nil, request),
    do: {:ok, %{request | show_version: true, command: nil}}

  defp decode_global(flag, _value, _request), do: usage("unknown global flag: #{flag}")

  defp decode_command([]),
    do: usage("a command is required (start, status, inspect, cancel, resume)")

  defp decode_command([{:flag, "--" <> _ = flag, _} | _]),
    do: usage("unknown flag before command: #{flag}")

  defp decode_command([{:positional, command} | rest]) do
    case Map.fetch(@command_lookup, command) do
      {:ok, atom} ->
        {:ok, atom, rest}

      :error ->
        usage(
          "unsupported command: #{command} (allowed: #{Enum.join(@supported_commands, ", ")})"
        )
    end
  end

  # -- per-command parsing --

  defp validate_command_body(command, tokens) do
    allowed = Map.fetch!(@command_flags, command)

    Enum.reduce_while(tokens, :ok, fn
      {:positional, value}, :ok ->
        {:halt, usage_result("unexpected positional argument: #{value}")}

      {:flag, "--" <> key, value}, :ok ->
        cond do
          key not in allowed -> {:halt, usage_result("unknown flag for #{command}: --#{key}")}
          value in [nil, :needs_value] -> {:halt, usage_result("--#{key} requires a value")}
          true -> {:cont, :ok}
        end
    end)
  end

  defp parse_options(command, tokens) do
    options =
      Enum.reduce(tokens, %{}, fn {:flag, "--" <> key, value}, acc ->
        if key in @repeating_flags do
          Map.update(acc, key, [value], &(&1 ++ [value]))
        else
          Map.put(acc, key, value)
        end
      end)

    case required_command_options(command, options) do
      :ok -> {:ok, options}
      {:error, _} = error -> error
    end
  end

  defp required_command_options(:start, options) do
    cond do
      not non_empty_option?(options, "repo") ->
        usage_result("--repo is required")

      not non_empty_option?(options, "objective") ->
        usage_result("--objective is required")

      not non_empty_list_option?(options, "criterion") ->
        usage_result("at least one --criterion is required")

      true ->
        :ok
    end
  end

  defp required_command_options(_command, _options), do: :ok

  defp non_empty_option?(options, key) do
    case Map.get(options, key) do
      value when is_binary(value) -> byte_size(value) > 0
      _ -> false
    end
  end

  defp non_empty_list_option?(options, key) do
    case Map.get(options, key) do
      [_ | _] = values -> Enum.all?(values, &(is_binary(&1) and byte_size(&1) > 0))
      _ -> false
    end
  end

  # -- helpers --

  defp parse_format(nil), do: :error
  defp parse_format("text"), do: {:ok, :text}
  defp parse_format("json"), do: {:ok, :json}
  defp parse_format(_), do: :error

  defp validate_kiln_home(value) when is_atom(value) or value in [nil, ""],
    do: usage("--kiln-home requires a path value")

  defp validate_kiln_home(value) when is_binary(value) and byte_size(value) == 0,
    do: usage("--kiln-home requires a path value")

  defp validate_kiln_home(value) when is_binary(value) do
    if Path.type(value) in [:absolute, :volumerelative, :relative] do
      cond do
        String.contains?(value, "\0") -> usage("--kiln-home contains a NUL byte")
        true -> {:ok, value}
      end
    else
      usage("--kiln-home must be a local path")
    end
  end

  defp validate_kiln_home(_other), do: usage("--kiln-home requires a path value")

  defp usage(message), do: usage_result(message)

  defp usage_result(message) do
    {:error, Result.to_error(message)}
  end

  defp base_request do
    %__MODULE__{command: nil, format: :text, kiln_home: nil}
  end

  @doc "The set of supported commands."
  @spec commands() :: [atom()]
  def commands, do: @supported_commands
end
