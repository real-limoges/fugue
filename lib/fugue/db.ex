defmodule Fugue.Db do
  @moduledoc """
  GenServer wrapping an HTTP connection to a CozoDB server.
  Provides `query/2` as the public API.
  """

  use GenServer

  require Logger

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Execute a CozoScript query with optional parameter bindings."
  def query(script, params \\ %{}) do
    GenServer.call(__MODULE__, {:query, script, params}, 30_000)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    url = Keyword.fetch!(opts, :url)
    auth_token = Keyword.get(opts, :auth_token)

    case ping(url, auth_token) do
      :ok ->
        {:ok, %{url: url, auth_token: auth_token}}

      {:error, reason} ->
        Logger.error("CozoDB not reachable at #{url}: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:query, script, params}, _from, state) do
    %{url: url, auth_token: auth_token} = state
    body = %{"script" => script, "params" => params}

    case Req.post("#{url}/text-query", json: body, headers: auth_headers(auth_token)) do
      {:ok, %Req.Response{status: 200, body: %{"ok" => true} = resp}} ->
        rows = resp["rows"] || []
        headers = resp["headers"] || []
        results = Enum.map(rows, fn row -> Map.new(Enum.zip(headers, row)) end)
        {:reply, {:ok, results}, state}

      {:ok, %Req.Response{body: %{"ok" => false, "display" => msg}}} ->
        {:reply, {:error, msg}, state}

      {:ok, %Req.Response{body: %{"ok" => false, "message" => msg}}} ->
        {:reply, {:error, msg}, state}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:reply, {:error, "CozoDB HTTP #{status}: #{inspect(body)}"}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # Helpers

  defp ping(url, auth_token) do
    body = %{"script" => "?[] <- [[1]]", "params" => %{}}

    case Req.post("#{url}/text-query", json: body, headers: auth_headers(auth_token)) do
      {:ok, %Req.Response{status: 200, body: %{"ok" => true}}} -> :ok
      {:ok, %Req.Response{status: s}} -> {:error, "CozoDB returned #{s}"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp auth_headers(nil), do: []
  defp auth_headers(token), do: [{"x-cozo-auth", token}]
end
