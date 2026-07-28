defmodule Kiln.Providers.OpenAICompatible do
  @moduledoc """
  Experimental direct transport for OpenAI-compatible model endpoints.

  This module owns HTTP request construction, JSON decoding, and stable error
  categories. It does not own session state, retries, tools, or provider event
  persistence.
  """

  alias Kiln.Providers.OpenAICompatible.Config

  @type error ::
          :unauthorized
          | :rate_limited
          | {:bad_request, map()}
          | {:upstream, non_neg_integer(), map()}
          | {:transport, term()}
          | {:invalid_json, non_neg_integer()}
          | {:invalid_response, term()}

  @spec list_models(Config.t()) :: {:ok, map()} | {:error, error()}
  def list_models(%Config{} = config) do
    request(:get, config, "/models", nil)
  end

  @spec chat(Config.t(), [map()], keyword()) :: {:ok, map()} | {:error, error() | atom()}
  def chat(%Config{} = config, messages, options \\ []) when is_list(messages) do
    with :ok <- validate_messages(messages) do
      body =
        %{
          "model" => config.model,
          "messages" => messages,
          "stream" => false
        }
        |> put_optional("temperature", Keyword.get(options, :temperature))
        |> put_optional("max_tokens", Keyword.get(options, :max_tokens))
        |> put_extra_body(Keyword.get(options, :extra_body, %{}))

      request(:post, config, "/chat/completions", body)
    end
  end

  def chat(%Config{}, _messages, _options), do: {:error, :invalid_messages}

  defp request(method, config, path, body) do
    url = config.base_url <> path
    headers = request_headers(config)
    http_options = [timeout: config.timeout, connect_timeout: config.timeout, autoredirect: false]
    response_options = [body_format: :binary]

    request =
      case body do
        nil ->
          {String.to_charlist(url), headers}

        value ->
          encoded = value |> :json.encode() |> IO.iodata_to_binary()
          {String.to_charlist(url), headers, ~c"application/json", encoded}
      end

    case :httpc.request(method, request, http_options, response_options) do
      {:ok, {{_version, status, _reason}, _headers, response_body}} ->
        decode_response(status, response_body)

      {:error, reason} ->
        {:error, {:transport, reason}}

      other ->
        {:error, {:invalid_response, other}}
    end
  end

  defp request_headers(config) do
    [
      {~c"authorization", String.to_charlist("Bearer " <> config.api_key)},
      {~c"accept", ~c"application/json"},
      {~c"user-agent", String.to_charlist(config.user_agent)}
    ]
  end

  defp decode_response(status, body) when status in 200..299 do
    case decode_json(body) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, :invalid_json} -> {:error, {:invalid_json, status}}
    end
  end

  defp decode_response(401, _body), do: {:error, :unauthorized}
  defp decode_response(403, _body), do: {:error, :unauthorized}
  defp decode_response(429, _body), do: {:error, :rate_limited}

  defp decode_response(status, body) when status in 400..499 do
    {:error, {:bad_request, safe_error_details(body)}}
  end

  defp decode_response(status, body) when status >= 500 do
    {:error, {:upstream, status, safe_error_details(body)}}
  end

  defp decode_response(status, _body), do: {:error, {:invalid_response, status}}

  defp decode_json(<<>>), do: {:ok, %{}}

  defp decode_json(body) when is_binary(body) do
    {:ok, :json.decode(body)}
  rescue
    _error -> {:error, :invalid_json}
  end

  defp safe_error_details(body) do
    case decode_json(body) do
      {:ok, decoded} when is_map(decoded) ->
        error = Map.get(decoded, <<"error">>, decoded)

        %{
          code: map_value(error, <<"code">>),
          type: map_value(error, <<"type">>),
          message: error |> map_value(<<"message">>) |> truncate_message()
        }
        |> Enum.reject(fn {_key, value} -> is_nil(value) end)
        |> Map.new()

      _other ->
        %{}
    end
  end

  defp map_value(value, key) when is_map(value), do: Map.get(value, key)
  defp map_value(_value, _key), do: nil

  defp truncate_message(value) when is_binary(value), do: String.slice(value, 0, 500)
  defp truncate_message(_value), do: nil

  defp validate_messages([]), do: {:error, :empty_messages}

  defp validate_messages(messages) do
    if Enum.all?(messages, &valid_message?/1) do
      :ok
    else
      {:error, :invalid_messages}
    end
  end

  defp valid_message?(%{"role" => role, "content" => content})
       when is_binary(role) and is_binary(content),
       do: true

  defp valid_message?(_message), do: false

  defp put_optional(body, _key, nil), do: body
  defp put_optional(body, key, value), do: Map.put(body, key, value)

  defp put_extra_body(body, extra) when is_map(extra), do: Map.merge(body, extra)
  defp put_extra_body(body, _extra), do: body
end
