defmodule Fugue.Ish do
  @moduledoc "HTTP client for the Ish mood analysis API."

  defp config, do: Application.get_env(:fugue, __MODULE__)
  defp base_url, do: config()[:url]

  defp req_opts do
    case config()[:gcp_auth] do
      true -> [headers: [{"authorization", "Bearer #{fetch_id_token()}"}]]
      _ -> []
    end
  end

  def health do
    Req.get("#{base_url()}/health", req_opts())
    |> parse_response()
  end

  def data do
    Req.get("#{base_url()}/data", req_opts())
    |> parse_response()
  end

  def entries(from \\ nil, to \\ nil) do
    params =
      [from: from, to: to]
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    Req.get("#{base_url()}/entries", Keyword.merge(req_opts(), params: params))
    |> parse_response()
  end

  def analysis do
    Req.get("#{base_url()}/analysis", req_opts())
    |> parse_response()
  end

  def clusters do
    Req.get("#{base_url()}/analysis/clusters", req_opts())
    |> parse_response()
  end

  def cluster(k, m) do
    Req.post("#{base_url()}/cluster", Keyword.merge(req_opts(), json: %{k: k, m: m}))
    |> parse_response()
  end

  def gaps do
    Req.get("#{base_url()}/gaps", req_opts())
    |> parse_response()
  end

  defp fetch_id_token do
    audience = base_url()

    url =
      "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity?audience=#{audience}"

    case Req.get(url, headers: [{"metadata-flavor", "Google"}]) do
      {:ok, %Req.Response{status: 200, body: token}} -> token
      other -> raise "Failed to fetch GCP ID token: #{inspect(other)}"
    end
  end

  defp parse_response({:ok, %Req.Response{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  defp parse_response({:ok, %Req.Response{status: status, body: body}}) do
    {:error, {status, body}}
  end

  defp parse_response({:error, _} = err), do: err
end
