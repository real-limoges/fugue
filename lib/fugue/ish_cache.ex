defmodule Fugue.IshCache do
  @moduledoc "ETS-backed cache for Ish API responses. Data is static, so results are cached indefinitely until server restart."

  use GenServer

  @table :ish_cache

  def start_link(_opts), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  @impl true
  def init(_) do
    :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    {:ok, nil}
  end

  @doc "Returns cached value for `key`, or calls `fetch_fn.()`, stores, and returns the result."
  def fetch(key, fetch_fn) do
    case :ets.lookup(@table, key) do
      [{^key, value}] ->
        value

      [] ->
        value = fetch_fn.()
        :ets.insert(@table, {key, value})
        value
    end
  end

  @doc "Clears the entire cache. Use when server-side state (e.g. membership functions) has changed."
  def invalidate_all do
    :ets.delete_all_objects(@table)
    :ok
  end
end
