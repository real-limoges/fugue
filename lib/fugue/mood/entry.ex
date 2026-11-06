defmodule Fugue.Mood.Entry do
  @moduledoc """
  One day of the mood journal, ported from Ish's `MoodEntry`.

  A day with no journal entry is still an `Entry` on the date spine
  (`Fugue.Mood.DataFrame.fill_missing_dates/1`), with every dimension
  `nil`; `complete?/1` tells the two apart.
  """

  @dimension_order [:sleep, :anxiety, :sensitivity, :outlook, :speed]

  @enforce_keys [:date]
  defstruct [:date, :sleep, :anxiety, :sensitivity, :outlook, :speed]

  @typedoc "A mood dimension's name, in `dimension_order/0`."
  @type dimension :: :sleep | :anxiety | :sensitivity | :outlook | :speed

  @type t :: %__MODULE__{
          date: Date.t(),
          sleep: float() | nil,
          anxiety: float() | nil,
          sensitivity: float() | nil,
          outlook: float() | nil,
          speed: float() | nil
        }

  @doc "The fixed dimension order used everywhere a mood entry becomes a point vector."
  @spec dimension_order() :: [dimension(), ...]
  def dimension_order, do: @dimension_order

  @doc "Build an entry from an ISO8601 date string and the 5 dimension values."
  @spec new(String.t(), float(), float(), float(), float(), float()) :: t()
  def new(date, sleep, anxiety, sensitivity, outlook, speed) do
    %__MODULE__{
      date: Date.from_iso8601!(date),
      sleep: sleep,
      anxiety: anxiety,
      sensitivity: sensitivity,
      outlook: outlook,
      speed: speed
    }
  end

  @doc "An absent day on the date spine: the date, every dimension `nil`."
  @spec absent(Date.t()) :: t()
  def absent(date), do: %__MODULE__{date: date}

  @doc "True when all 5 dimensions are present (non-nil)."
  @spec complete?(t()) :: boolean()
  def complete?(entry), do: Enum.all?(@dimension_order, &(not is_nil(Map.fetch!(entry, &1))))

  @doc """
  The entry's dimensions as a `[sleep, anxiety, sensitivity, outlook, speed]`
  point vector. Only meaningful for a `complete?/1` entry.
  """
  @spec point(t()) :: [float()]
  def point(entry), do: Enum.map(@dimension_order, &Map.fetch!(entry, &1))
end
