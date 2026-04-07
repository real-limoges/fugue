defmodule Fugue.Ish do
  @moduledoc "HTTP client for the Ish mood analysis API."

  def base_url, do: Application.get_env(:fugue, __MODULE__)[:url]

  def health do
    Req.get("#{base_url()}/health")
    |> parse_response()
  end

  def data do
    Req.get("#{base_url()}/data")
    |> parse_response()
  end

  def entries(from \\ nil, to \\ nil) do
    params =
      [from: from, to: to]
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    Req.get("#{base_url()}/entries", params: params)
    |> parse_response()
  end

  def analysis do
    Req.get("#{base_url()}/analysis")
    |> parse_response()
  end

  def clusters do
    Req.get("#{base_url()}/analysis/clusters")
    |> parse_response()
  end

  def cluster(k, m) do
    Req.post("#{base_url()}/cluster", json: %{k: k, m: m})
    |> parse_response()
  end

  def gaps do
    Req.get("#{base_url()}/gaps")
    |> parse_response()
  end

  defp parse_response({:ok, %Req.Response{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  defp parse_response({:ok, %Req.Response{status: status, body: body}}) do
    {:error, {status, body}}
  end

  defp parse_response({:error, _} = err), do: err
end
