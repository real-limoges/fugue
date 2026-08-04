defmodule Fugue.Mood.MembershipState do
  @moduledoc """
  Holds the current membership-function defs, mirroring Ish's
  `AppEnv.envMembershipFns` (a bare `IORef`): initialized to
  `Fugue.Mood.Fuzzify.default_membership_func_defs/0` on start, mutated
  only via `put/1` with no validation, never persisted -- a deploy/restart
  resets to defaults.
  """

  use GenServer

  alias Fugue.Mood.Fuzzify

  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, nil, Keyword.put(opts, :name, name))
  end

  @doc "The current membership-function defs."
  def current(server \\ __MODULE__), do: GenServer.call(server, :current)

  @doc "Replace the current membership-function defs wholesale. No validation, matching Ish."
  def put(defs, server \\ __MODULE__), do: GenServer.call(server, {:put, defs})

  @impl true
  def init(_), do: {:ok, Fuzzify.default_membership_func_defs()}

  @impl true
  def handle_call(:current, _from, state), do: {:reply, state, state}

  def handle_call({:put, defs}, _from, _state), do: {:reply, defs, defs}
end
