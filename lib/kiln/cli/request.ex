defmodule Kiln.CLI.Request do
  @moduledoc """
  Bounded parser for the foundation CLI request.

  This parser handles only the P1-S01 surface: global flags
  (`--format`, `--kiln-home`, `--actor-id`, `--help`, `--version`), and the
  commands `start`, `status`, `inspect`, `cancel`, and `resume`. Anything
  else resolves to a structured usage error that the renderer formats; the
  CLI never falls back to a framework or silently treats it as success.

  Parsing is total: a malformed flag, an unknown command, or a missing
  required option returns `{:error, error}` with a stable
  `USAGE_ERROR` code. The CLI is non-authoritative, so this module never
  touches the database, provider, Repository, or model.

  `--actor-id` may be supplied explicitly. When the flag is absent, the
  parser consults the `KILN_ACTOR_ID` environment variable. When both are
  absent or blank, the parser returns a structured `USAGE_ERROR` so the
  dispatcher never silently defaults to a placeholder actor.

  `--kiln-home` resolution follows `docs/CLI-AND-LOCAL-DELIVERY-CONTRACT.md`:
    1. explicit `--kiln-home PATH` (absolute, normalised; relative rejected);
    2. `KILN_HOME` environment variable (absolute; relative rejected);
    3. default `~/Library/Application Support/Kiln` (canonicalised).

  The resolved `kiln_home` is canonicalised to an absolute, normalised path
  before the request is returned. A `nil` `kiln_home` never reaches the
  dispatcher.
  """

  alias Kiln.CLI.Result

  @supported_commands [:start, :status, :inspect, :cancel, :resume, :supervise]
  @command_lookup Map.new(@supported_commands, &{Atom.to_string(&1), &1})

  # The accepted default home directory. Matches
  # `docs/CLI-AND-LOCAL-DELIVERY-CONTRACT.md` §3.1 rule 9.
  @default_kiln_home "~/Library/Application Support/Kiln"

  @enforce_keys [:command]
  defstruct command: nil,
            format: nil,
            kiln_home: nil,
            actor_id: nil,
            show_help: false,
            show_version: false,
            options: %{},
            positional: []

  @type format :: :text | :json

  @type t :: %__MODULE__{
          command: atom() | nil,
          format: format(),
          kiln_home: String.t() | nil,
          actor_id: String.t() | nil,
          show_help: boolean(),
          show_version: boolean(),
          options: map(),
          positional: [String.t()]
        }

  @doc "Parse argv into a request or a structured usage error."
  @spec parse([String.t()]) :: {:ok, t()} | {:error, Result.error()}
  def parse(argv) when is_list(argv) do
    parse(argv, fn key -> System.get_env(key) end)
  end

  @doc """
  Parse argv with an injected environment reader.

  `env_reader` is `fn atom -> String.t() | nil end`. It exists so tests can
  drive the KILN_HOME / KILN_ACTOR_ID fallback deterministically without
  mutating the process environment.
  """
  @spec parse([String.t()], (atom() -> String.t() | nil)) ::
          {:ok, t()} | {:error, Result.error()}
  def parse(argv, env_reader) when is_list(argv) and is_function(env_reader, 1) do
    case tokenize(argv) do
      {:ok, tokens} -> decode(tokens, env_reader)
      {:error, _} = error -> error
    end
  end

  # -- tokenization --

  @value_flags ~w(--format --kiln-home --actor-id --repo --objective --criterion --constraint --exclude --reason --work-envelope)
  @repeating_flags ~w(criterion constraint exclude)
  @command_flags %{
    start: ~w(repo objective criterion constraint exclude),
    status: [],
    inspect: [],
    cancel: ~w(reason),
    resume: [],
    supervise: ~w(work-envelope)
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

  defp decode(tokens, env_reader) do
    tokens = consume_value_flags(tokens, [])

    {globals, rest} =
      Enum.split_with(tokens, fn
        {:flag, "--format", _} -> true
        {:flag, "--kiln-home", _} -> true
        {:flag, "--actor-id", _} -> true
        {:flag, "--help", _} -> true
        {:flag, "--version", _} -> true
        _ -> false
      end)

    with {:ok, %__MODULE__{} = global_opts} <- decode_globals(globals, base_request()) do
      with {:ok, %__MODULE__{} = global_opts} <- resolve_kiln_home(global_opts, env_reader) do
        cond do
          global_opts.show_help or global_opts.show_version ->
            {:ok, global_opts}

          true ->
            with {:ok, %__MODULE__{} = global_opts} <- resolve_actor_id(global_opts, env_reader) do
              decode_command_into(global_opts, rest)
            end
        end
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

  defp decode_global("--actor-id", value, request) do
    case validate_actor_id(value) do
      {:ok, actor_id} -> {:ok, %{request | actor_id: actor_id, command: nil}}
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

  defp required_command_options(:supervise, options) do
    if non_empty_option?(options, "work-envelope") do
      :ok
    else
      usage_result("--work-envelope is required")
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
    cond do
      String.contains?(value, "\0") ->
        usage("--kiln-home contains a NUL byte")

      Path.type(value) != :absolute ->
        usage("--kiln-home must be an absolute path")

      true ->
        {:ok, canonicalise_path(value)}
    end
  end

  defp validate_kiln_home(_other), do: usage("--kiln-home requires a path value")

  # Expand to an absolute path and collapse `..` / `.` segments before the
  # dispatcher ever sees the value. The CLI promise: the request always
  # carries an absolute, normalised kiln_home.
  defp canonicalise_path(value) do
    value
    |> Path.expand()
    |> Path.absname()
  end

  defp validate_actor_id(value) when is_binary(value) do
    trimmed = String.trim(value)

    if byte_size(trimmed) == 0 do
      usage("--actor-id must be a non-blank string")
    else
      {:ok, trimmed}
    end
  end

  defp validate_actor_id(_other), do: usage("--actor-id requires a non-blank value")

  # Resolve the actor_id when the flag is absent. The env lookup happens
  # only after the explicit flag has been honoured; an explicit `--actor-id ""`
  # still fails the validate_actor_id check above. A blank env value fails
  # the same way; there is no implicit default.
  defp resolve_actor_id(%__MODULE__{actor_id: actor_id} = request, _env_reader)
       when is_binary(actor_id) and byte_size(actor_id) > 0,
       do: {:ok, request}

  defp resolve_actor_id(%__MODULE__{actor_id: nil} = request, env_reader) do
    case env_reader.("KILN_ACTOR_ID") do
      nil ->
        usage("an actor_id is required (pass --actor-id or set KILN_ACTOR_ID)")

      "" ->
        usage("an actor_id is required (pass --actor-id or set KILN_ACTOR_ID)")

      value ->
        validate_actor_id(value)
        |> case do
          {:ok, resolved} -> {:ok, %{request | actor_id: resolved}}
          {:error, _} = error -> error
        end
    end
  end

  defp resolve_actor_id(%__MODULE__{} = request, _env_reader), do: {:ok, request}

  # Resolve `kiln_home` from explicit flag → `KILN_HOME` env →
  # `@default_kiln_home`. Every layer is canonicalised via
  # `validate_kiln_home/1` so a relative env value is rejected with the
  # same USAGE_ERROR as a relative flag value. The resolved value is
  # always an absolute, normalised path; `nil` never reaches the
  # dispatcher.
  defp resolve_kiln_home(%__MODULE__{kiln_home: path} = request, _env_reader)
       when is_binary(path) and byte_size(path) > 0,
       do: {:ok, request}

  defp resolve_kiln_home(%__MODULE__{kiln_home: nil} = request, env_reader) do
    case env_reader.("KILN_HOME") do
      nil ->
        apply_default_kiln_home(request)

      "" ->
        apply_default_kiln_home(request)

      value ->
        case validate_kiln_home(value) do
          {:ok, path} -> {:ok, %{request | kiln_home: path}}
          {:error, _} = error -> error
        end
    end
  end

  # The default uses `~` which `Path.type/1` reports as `:relative` until
  # expanded. The default itself is trusted (it ships in source); only
  # the *user-supplied* flag/env path is rejected when relative.
  defp apply_default_kiln_home(%__MODULE__{} = request) do
    canonical =
      @default_kiln_home
      |> Path.expand()
      |> Path.absname()

    {:ok, %{request | kiln_home: canonical}}
  end

  defp usage(message), do: usage_result(message)

  defp usage_result(message) do
    {:error, Result.to_error(message)}
  end

  defp base_request do
    %__MODULE__{command: nil, format: :text, kiln_home: nil, actor_id: nil}
  end

  @doc "The set of supported commands."
  @spec commands() :: [atom()]
  def commands, do: @supported_commands
end
