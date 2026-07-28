defmodule Kiln.Providers.OpenAICompatible.Config do
  @moduledoc """
  Validated configuration for one OpenAI-compatible provider endpoint.

  The configuration contains a runtime credential. Callers must not persist,
  inspect, or include the credential in logs and errors.
  """

  @enforce_keys [:base_url, :api_key, :model]
  defstruct [:base_url, :api_key, :model, timeout: 60_000, user_agent: "kiln/0.1.0-dev"]

  @type t :: %__MODULE__{
          base_url: String.t(),
          api_key: String.t(),
          model: String.t(),
          timeout: pos_integer(),
          user_agent: String.t()
        }

  @spec new(keyword()) :: {:ok, t()} | {:error, atom()}
  def new(options) when is_list(options) do
    base_url = options |> Keyword.get(:base_url) |> normalize_string()
    api_key = options |> Keyword.get(:api_key) |> normalize_string()
    model = options |> Keyword.get(:model) |> normalize_string()
    timeout = Keyword.get(options, :timeout, 60_000)
    user_agent = options |> Keyword.get(:user_agent, "kiln/0.1.0-dev") |> normalize_string()

    with :ok <- validate_url(base_url),
         :ok <- require_value(api_key, :missing_api_key),
         :ok <- require_value(model, :missing_model),
         :ok <- validate_timeout(timeout),
         :ok <- require_value(user_agent, :missing_user_agent) do
      {:ok,
       %__MODULE__{
         base_url: String.trim_trailing(base_url, "/"),
         api_key: api_key,
         model: model,
         timeout: timeout,
         user_agent: user_agent
       }}
    end
  end

  def new(_options), do: {:error, :invalid_options}

  defp normalize_string(value) when is_binary(value), do: String.trim(value)
  defp normalize_string(_value), do: ""

  defp validate_url(value) do
    case URI.parse(value) do
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and is_binary(host) ->
        :ok

      _other ->
        {:error, :invalid_base_url}
    end
  end

  defp require_value("", reason), do: {:error, reason}
  defp require_value(_value, _reason), do: :ok

  defp validate_timeout(value) when is_integer(value) and value > 0, do: :ok
  defp validate_timeout(_value), do: {:error, :invalid_timeout}
end
