defmodule FugueWeb.MoodLive.Structs do
  @moduledoc "Data structures for the Mood Explorer LiveView."

  defmodule AnalysisResult do
    @moduledoc "Clustering result, parsed from `Fugue.Mood.Wire.cluster/4`."

    defstruct [
      :clusters,
      :membership,
      :cluster_colors,
      :name_to_id,
      :cluster_names,
      :cluster_ids,
      :raw_centroids,
      :fpc,
      :iterations
    ]
  end

  defmodule CalendarDay do
    @moduledoc "A single day rendered on the calendar heatmap."
    defstruct [:date, :dimensions, :memberships, :is_gap]
  end

  defmodule GapData do
    @moduledoc "Gap analysis, parsed from `Fugue.Mood.Wire.gaps/2`."
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
