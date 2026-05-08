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

  def data(from \\ nil, to \\ nil) do
    IshCache.fetch({:data, from, to}, fn ->
      get("/data", date_params(from, to)) |> parse_response()
    end)
  end

  def entries(from \\ nil, to \\ nil) do
    get("/entries", date_params(from, to)) |> parse_response()
  end

  def analysis(from \\ nil, to \\ nil) do
    get("/analysis", date_params(from, to)) |> parse_response()
  end

  def clusters(from \\ nil, to \\ nil) do
    get("/analysis/clusters", date_params(from, to)) |> parse_response()
  end

  def cluster(k, m, from \\ nil, to \\ nil) do
    IshCache.fetch({:cluster, k, m, from, to}, fn ->
      post("/cluster", json: %{k: k, m: m}, params: date_params(from, to))
      |> parse_response()
    end)
  end

  def gaps(from \\ nil, to \\ nil) do
    IshCache.fetch({:gaps, from, to}, fn ->
      get("/gaps", date_params(from, to)) |> parse_response()
    end)
  end

  def membership_functions do
    Req.get("#{base_url()}/membership-functions", req_opts()) |> parse_response()
  end

  def update_membership_functions(defs) do
    with {:ok, _} = ok <- post("/membership-functions", json: defs) |> parse_response() do
      IshCache.invalidate_all()
      ok
    end
  end

  def suggest_membership_functions do
    post("/membership-functions/suggest", []) |> parse_response()
  end

  def mamdani(request) do
    post("/inference/mamdani", json: request) |> parse_response()
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

  defp get(path, params) do
    Req.get("#{base_url()}#{path}", Keyword.merge(req_opts(), params: params))
  end

  defp post(path, opts) do
    Req.post("#{base_url()}#{path}", Keyword.merge(req_opts(), opts))
  end

  defp date_params(from, to) do
    [from: from, to: to] |> Enum.reject(fn {_k, v} -> is_nil(v) end)
  end
end
