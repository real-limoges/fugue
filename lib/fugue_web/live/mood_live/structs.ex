defmodule FugueWeb.MoodLive.Structs do
  @moduledoc "Data structures for the Mood Explorer LiveView."

  defmodule AnalysisResult do
    @moduledoc "Parsed result from Ish clustering API."
    defstruct [:clusters, :membership, :cluster_colors, :name_to_id, :fpc, :iterations]
  end

  defmodule CalendarDay do
    @moduledoc "A single day rendered on the calendar heatmap."
    defstruct [:date, :dimensions, :memberships, :is_gap]

    def to_event(%__MODULE__{} = day) do
      %{
        date: day.date,
        dimensions: day.dimensions,
        memberships: day.memberships,
        isGap: day.is_gap
      }
    end
  end

  defmodule ScatterPoint do
    @moduledoc "A single point in the scatter plot."
    defstruct [:date, :values, :memberships]

    def to_event(%__MODULE__{} = p) do
      %{date: p.date, values: p.values, memberships: p.memberships}
    end
  end

  defmodule GapData do
    @moduledoc "Parsed gap analysis from Ish API."
    defstruct [:transitions, :length_distribution, :imputed_memberships]

    def from_api(nil), do: nil

    def from_api(raw) when is_map(raw) do
      %__MODULE__{
        transitions: raw["transitions"] || [],
        length_distribution: raw["lengthDistribution"] || %{},
        imputed_memberships: raw["imputedMemberships"] || %{}
      }
    end
  end
end
