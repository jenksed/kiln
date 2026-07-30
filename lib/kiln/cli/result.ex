defmodule Kiln.CLI.Result do
  @moduledoc """
  Stable result envelope for the foundation CLI.

  Every command returns a `Kiln.CLI.Result.t/0` whose text and JSON views describe
  equivalent authoritative state. The envelope follows the `kiln.cli.result/v1`
  schema from `docs/contracts/kiln-first-month.schema.json` and the exit code map
  from the accepted CLI and local delivery contract.

  CLI rendering is never domain authority: this module only shapes data the
  parser, dispatcher, and renderer already agreed on. Constructing or mutating
  results here does not change the underlying Session, journal, or projection.
  """

  @schema "kiln.cli.result/v1"
  @kind "cli_result"

  @statuses [:ok, :denied, :blocked, :stale, :failed, :unknown, :unsupported]

  @exit_map %{
    ok: 0,
    denied: 3,
    blocked: 4,
    stale: 5,
    failed: 6,
    unknown: 7,
    unsupported: 9
  }
  @accepted_exit_codes [0, 2, 3, 4, 5, 6, 7, 8, 9, 10]

  @type status :: :ok | :denied | :blocked | :stale | :failed | :unknown | :unsupported

  @type error :: %{
          code: String.t(),
          class: String.t(),
          message: String.t(),
          details: map()
        }

  @type warning :: %{code: String.t(), message: String.t()}

  @type next_action :: %{action: String.t(), description: String.t()}

  @type data :: map() | list() | nil

  @type t :: %__MODULE__{
          command: String.t(),
          status: status(),
          exit_code: non_neg_integer(),
          data: data(),
          errors: [error()],
          warnings: [warning()],
          next_actions: [next_action()],
          session_revision: non_neg_integer() | nil,
          journal_digest: String.t() | nil,
          emitted_at: String.t()
        }

  @enforce_keys [:command, :status]
  defstruct command: nil,
            status: nil,
            exit_code: 0,
            session_revision: nil,
            journal_digest: nil,
            emitted_at: nil,
            data: nil,
            errors: [],
            warnings: [],
            next_actions: []

  @doc "The versioned envelope identifier."
  @spec schema() :: String.t()
  def schema, do: @schema

  @doc "The schema `kind` literal used in the JSON envelope."
  @spec kind() :: String.t()
  def kind, do: @kind

  @doc "The accepted CLI statuses."
  @spec statuses() :: [status()]
  def statuses, do: @statuses

  @doc "Map a status to its accepted exit code."
  @spec exit_for(status()) :: non_neg_integer()
  def exit_for(status) when status in @statuses, do: Map.fetch!(@exit_map, status)

  @doc "Build an `ok` result with the given payload."
  @spec ok(String.t(), keyword()) :: t()
  def ok(command, opts \\ []) do
    build(command, :ok,
      exit_code: Keyword.get(opts, :exit_code, exit_for(:ok)),
      data: Keyword.get(opts, :data),
      warnings: Keyword.get(opts, :warnings, []),
      next_actions: Keyword.get(opts, :next_actions, []),
      session_revision: Keyword.get(opts, :session_revision),
      journal_digest: Keyword.get(opts, :journal_digest)
    )
  end

  @doc "Build a non-ok result with structured `error` facts."
  @spec error(String.t(), status(), keyword()) :: t()
  def error(command, status, opts) when status in @statuses do
    build(command, status,
      exit_code: Keyword.get(opts, :exit_code, exit_for(status)),
      data: Keyword.get(opts, :data),
      errors: Keyword.get(opts, :errors, []),
      warnings: Keyword.get(opts, :warnings, []),
      next_actions: Keyword.get(opts, :next_actions, []),
      session_revision: Keyword.get(opts, :session_revision),
      journal_digest: Keyword.get(opts, :journal_digest)
    )
  end

  defp build(command, status, opts) do
    exit_code = Keyword.get(opts, :exit_code, exit_for(status))

    unless exit_code in @accepted_exit_codes do
      raise ArgumentError, "unsupported CLI exit code: #{inspect(exit_code)}"
    end

    %__MODULE__{
      command: command,
      status: status,
      exit_code: exit_code,
      data: Keyword.get(opts, :data),
      errors: Keyword.get(opts, :errors, []),
      warnings: Keyword.get(opts, :warnings, []),
      next_actions: Keyword.get(opts, :next_actions, []),
      session_revision: Keyword.get(opts, :session_revision),
      journal_digest: Keyword.get(opts, :journal_digest),
      emitted_at: Keyword.get(opts, :emitted_at, utc_now_iso())
    }
  end

  @doc "Build one bounded structured error entry from a domain or store error."
  @spec to_error(map() | atom() | String.t()) :: error()
  def to_error(%{code: code, message: message} = error) do
    %{
      code: to_code(code),
      class: to_class(error),
      message: message,
      details: Map.get(error, :details, %{}) |> stringify_keys()
    }
  end

  def to_error(%{code: code}) when is_atom(code) do
    to_error(%{code: code, message: Atom.to_string(code)})
  end

  def to_error(value) when is_atom(value) do
    to_error(%{code: value, message: Atom.to_string(value)})
  end

  def to_error(value) when is_binary(value) do
    %{code: "USAGE_ERROR", class: "usage", message: value, details: %{}}
  end

  @doc "Build one bounded structured warning entry."
  @spec warning(String.t(), String.t()) :: warning()
  def warning(code, message) when is_binary(code) and is_binary(message),
    do: %{code: code, message: message}

  @doc "Build one bounded next-action suggestion."
  @spec next_action(String.t(), String.t()) :: next_action()
  def next_action(action, description) when is_binary(action) and is_binary(description),
    do: %{action: action, description: description}

  defp to_code(code) when is_atom(code), do: upcase(code)
  defp to_code(code) when is_binary(code), do: code

  defp to_class(%{class: class}) when is_binary(class), do: class
  defp to_class(%{code: :stale_revision}), do: "stale_revision"
  defp to_class(%{code: :revision}), do: "stale_revision"
  defp to_class(%{code: :integrity}), do: "integrity"
  defp to_class(%{code: :idempotency_conflict}), do: "idempotency"
  defp to_class(%{code: :store_busy}), do: "store_busy"
  defp to_class(%{code: :busy}), do: "store_busy"
  defp to_class(%{code: :unknown}), do: "unknown"
  defp to_class(%{class: :busy}), do: "store_busy"
  defp to_class(%{class: class}) when is_atom(class), do: Atom.to_string(class)
  defp to_class(_), do: "domain"

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), stringify_keys(v)} end)
  end

  defp stringify_keys(list) when is_list(list), do: Enum.map(list, &stringify_keys/1)
  defp stringify_keys(value), do: value

  defp upcase(atom) do
    atom |> Atom.to_string() |> String.upcase()
  end

  defp utc_now_iso do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end
end
