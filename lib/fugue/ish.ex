defmodule Fugue.Ish do
  @moduledoc "HTTP client for the Ish mood analysis API."

  alias Fugue.IshCache

  defp config, do: Application.get_env(:fugue, __MODULE__)
  defp base_url, do: config()[:url]

  defp req_opts do
    base =
      case config()[:plug] do
        nil -> []
        plug -> [plug: plug, retry: false]
      end

    case config()[:gcp_auth] do
      true -> Keyword.put(base, :headers, [{"authorization", "Bearer #{fetch_id_token()}"}])
      _ -> base
    end
  end

  def health do
    Req.get("#{base_url()}/health", req_opts())
    |> parse_response()
  end

  def data do
    IshCache.fetch(:data, fn ->
      Req.get("#{base_url()}/data", req_opts()) |> parse_response()
    end)
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
    IshCache.fetch({:cluster, k, m}, fn ->
      Req.post("#{base_url()}/cluster", Keyword.merge(req_opts(), json: %{k: k, m: m}))
      |> parse_response()
    end)
  end

  def gaps do
    IshCache.fetch(:gaps, fn ->
      Req.get("#{base_url()}/gaps", req_opts()) |> parse_response()
    end)
  end

  def membership_functions do
    Req.get("#{base_url()}/membership-functions", req_opts()) |> parse_response()
  end

  def update_membership_functions(defs) do
    result =
      Req.post("#{base_url()}/membership-functions", Keyword.merge(req_opts(), json: defs))
      |> parse_response()

    case result do
      {:ok, _} = ok ->
        IshCache.invalidate_all()
        ok

      err ->
        err
    end
  end

  def suggest_membership_functions do
    Req.post("#{base_url()}/membership-functions/suggest", req_opts()) |> parse_response()
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
