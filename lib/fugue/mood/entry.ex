defmodule Fugue.Mood.Entry do
  @moduledoc """
  Shape reference for a mood entry, ported from Ish's `MoodEntry`. A plain
  map: `%{date: Date.t(), sleep: float(), anxiety: float(), sensitivity:
  float(), outlook: float(), speed: float()}`.
  """

  @dimension_order [:sleep, :anxiety, :sensitivity, :outlook, :speed]

  @doc "The fixed dimension order used everywhere a mood entry becomes a point vector."
  def dimension_order, do: @dimension_order

  @doc "Build an entry from an ISO8601 date string and the 5 dimension values."
  def new(date, sleep, anxiety, sensitivity, outlook, speed) do
    %{
      date: Date.from_iso8601!(date),
      sleep: sleep,
      anxiety: anxiety,
      sensitivity: sensitivity,
      outlook: outlook,
      speed: speed
    }
  end

  @doc "True when all 5 dimensions are present (non-nil) on the given row."
  def complete?(row), do: Enum.all?(@dimension_order, &(not is_nil(Map.get(row, &1))))

  @doc "The entry's dimensions as a `[sleep, anxiety, sensitivity, outlook, speed]` point vector."
  def point(row), do: Enum.map(@dimension_order, &Map.get(row, &1))
end
