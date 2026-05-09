defmodule FugueWeb.MoodLive.Focus do
  @moduledoc """
  Single-focus state for `/mood`.

  At most one of `{day, cluster, gap}` is focused at a time. See
  `CONTEXT.md` "Focus (mood)" for the domain definition.

  Pure module: transitions take and return a focus value, derived
  projections take a focus and the relevant data. No socket, no IO.
  """

  alias FugueWeb.MoodLive.Structs.GapData

  @type date :: String.t()
  @type cluster :: String.t()
  @type gap :: %{optional(String.t()) => term()}
  @type t :: :none | {:day, date()} | {:cluster, cluster()} | {:gap, gap()}

  # --- Transitions -----------------------------------------------------

  @spec select_day(t(), date()) :: t()
  def select_day(_focus, date), do: {:day, date}

  @spec select_cluster(t(), cluster()) :: t()
  def select_cluster({:cluster, cluster}, cluster), do: :none
  def select_cluster(_focus, cluster), do: {:cluster, cluster}

  @spec select_gap(t(), gap()) :: t()
  def select_gap(_focus, gap), do: {:gap, gap}

  @spec clear(t()) :: t()
  def clear(_focus), do: :none

  # --- Derived projections ---------------------------------------------

  @doc """
  Dates lit on calendar / timeline. Brush range fills the set;
  `{:day, d}` overrides to `[d]`. Cluster and gap focuses contribute
  no dates.
  """
  @spec highlights(t(), {date(), date()} | nil, [map()]) :: [date()]
  def highlights({:day, d}, _brush, _entries), do: [d]
  def highlights(_focus, nil, _entries), do: []

  def highlights(_focus, {start, end_date}, entries) do
    entries
    |> Enum.map(& &1["date"])
    |> Enum.filter(fn d -> d >= start and d <= end_date end)
  end

  @doc """
  Filter `gaps.transitions` to those involving the focused cluster (>=0.3
  membership before or after). When not focused on a cluster, returns the
  full transition list. Returns `[]` when gaps haven't loaded.
  """
  @spec gap_transitions(%GapData{} | nil, t()) :: list()
  def gap_transitions(nil, _focus), do: []

  def gap_transitions(%GapData{transitions: transitions}, {:cluster, cluster}) do
    Enum.filter(transitions, fn t ->
      before = t["before"] || %{}
      after_m = t["after"] || %{}
      Map.get(before, cluster, 0) >= 0.3 or Map.get(after_m, cluster, 0) >= 0.3
    end)
  end

  def gap_transitions(%GapData{transitions: transitions}, _focus), do: transitions
end
