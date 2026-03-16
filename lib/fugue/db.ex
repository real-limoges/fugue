defmodule Fugue.Db do
  @moduledoc """
  GenServer wrapper around a surrealix WebSocket connection.
  Provides `query/2` and `select/1` as the public API.
  """

  use GenServer

  require Logger

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Execute a SurrealQL query with optional variable bindings."
  def query(sql, vars \\ %{}) do
    GenServer.call(__MODULE__, {:query, sql, vars})
  end

  @doc "Select a record by its SurrealDB ID (e.g. \"article:42\")."
  def select(thing) do
    GenServer.call(__MODULE__, {:select, thing})
  end

  # Server callbacks

  @impl true
  def init(opts) do
    hostname = Keyword.fetch!(opts, :hostname)
    port = Keyword.fetch!(opts, :port)
    namespace = Keyword.fetch!(opts, :namespace)
    database = Keyword.fetch!(opts, :database)
    username = Keyword.fetch!(opts, :username)
    password = Keyword.fetch!(opts, :password)

    case connect(hostname, port, namespace, database, username, password) do
      {:ok, pid} ->
        Process.monitor(pid)
        {:ok, %{pid: pid, config: opts}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:query, sql, vars}, _from, %{pid: pid} = state) do
    case Surrealix.query(pid, sql, vars) do
      {:ok, %{"result" => results}} ->
        {:reply, {:ok, results}, state}

      {:ok, result} ->
        {:reply, {:ok, result}, state}

      {:error, _} = err ->
        {:reply, err, state}
    end
  end

  def handle_call({:select, thing}, _from, %{pid: pid} = state) do
    case Surrealix.select(pid, thing) do
      {:ok, %{"result" => result}} ->
        {:reply, {:ok, result}, state}

      {:ok, result} ->
        {:reply, {:ok, result}, state}

      {:error, _} = err ->
        {:reply, err, state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, reason}, %{config: opts} = state) do
    Logger.warning("SurrealDB connection lost: #{inspect(reason)}, reconnecting...")

    case connect(
           Keyword.fetch!(opts, :hostname),
           Keyword.fetch!(opts, :port),
           Keyword.fetch!(opts, :namespace),
           Keyword.fetch!(opts, :database),
           Keyword.fetch!(opts, :username),
           Keyword.fetch!(opts, :password)
         ) do
      {:ok, pid} ->
        Process.monitor(pid)
        {:noreply, %{state | pid: pid}}

      {:error, reason} ->
        {:stop, reason, state}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # Helpers

  defp connect(hostname, port, namespace, database, username, password) do
    with {:ok, pid} <- Surrealix.start_link(hostname: hostname, port: port),
         {:ok, _} <- Surrealix.signin(pid, %{"user" => username, "pass" => password}),
         {:ok, _} <- Surrealix.use(pid, namespace, database) do
      {:ok, pid}
    end
  end
end
