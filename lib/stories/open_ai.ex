defmodule Stories.OpenAi do
  @completions_url "https://api.openai.com/v1/chat/completions"
  @generations_url "https://api.openai.com/v1/images/generations"

  def generate_image(prompt) do
    headers = headers()
    body = Jason.encode!(generations_body(prompt))

    response =
      HTTPoison.post!(@generations_url, body, headers, timeout: 60_000, recv_timeout: 60_000)

    response.body |> Jason.decode!(keys: :atoms) |> Map.get(:data) |> hd() |> Map.get(:b64_json)
  end

  def stream(prompt) do
    body = Jason.encode!(completions_body(prompt, true))
    headers = headers()

    Stream.resource(
      fn -> HTTPoison.post!(@completions_url, body, headers, stream_to: self(), async: :once) end,
      &handle_async_response/1,
      &close_async_response/1
    )
  end

  defp close_async_response(resp), do: :hackney.stop_async(resp)
  defp handle_async_response({:done, resp}), do: {:halt, resp}

  defp handle_async_response(%HTTPoison.AsyncResponse{id: id} = resp) do
    receive do
      %HTTPoison.AsyncStatus{id: ^id} ->
        HTTPoison.stream_next(resp)
        {[], resp}

      %HTTPoison.AsyncHeaders{id: ^id} ->
        HTTPoison.stream_next(resp)
        {[], resp}

      %HTTPoison.AsyncChunk{id: ^id, chunk: chunk} ->
        HTTPoison.stream_next(resp)
        parse_chunk(chunk, resp)

      %HTTPoison.AsyncEnd{id: ^id} ->
        {:halt, resp}
    end
  end

  defp parse_chunk(chunk, resp) do
    {chunk, done?} =
      chunk
      |> String.split("data:")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.reduce({"", false}, fn trimmed, {chunk, is_done?} ->
        case Jason.decode(trimmed) do
          {:ok, %{"choices" => [%{"delta" => %{"content" => text}}]}} ->
            {chunk <> text, is_done? or false}

          {:ok, %{"choices" => [%{"delta" => _delta}]}} ->
            {chunk, is_done? or false}

          {:error, %{data: "[DONE]"}} ->
            {chunk, is_done? or true}
        end
      end)

    if done?,
      do: {[chunk], {:done, resp}},
      else: {[chunk], resp}
  end

  defp headers do
    [
      Accept: "application/json",
      "Content-Type": "application/json",
      Authorization: "Bearer #{System.get_env("OPENAI_KEY")}"
    ]
  end

  defp generations_body(prompt) do
    %{
      model: "dall-e-3",
      prompt: prompt,
      n: 1,
      size: "1024x1024",
      response_format: "b64_json"
    }
  end

  defp completions_body(prompt, streaming?) do
    %{
      model: "gpt-3.5-turbo",
      messages: [%{role: "user", content: prompt}],
      stream: streaming?,
      max_tokens: 1024
    }
  end
end
