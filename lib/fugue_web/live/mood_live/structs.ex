defmodule FugueWeb.MoodLive.Structs do
  @moduledoc "Data structures for the Mood Explorer LiveView."

  defmodule AnalysisResult do
    @moduledoc "Clustering result, parsed from `Fugue.Mood.Wire.cluster/4`."

    alias FugueWeb.MoodLive.DataTransforms

    defstruct [
      :clusters,
      :membership,
      :cluster_colors,
      :name_to_id,
      :cluster_names,
      :cluster_ids,
      :raw_centroids,
      :iterations
    ]

    @typedoc """
    `membership` is a tuple of rows, one per entry in entry order, each a
    tuple of degrees in cluster order: tuples for O(1) indexed access.
    """
    @type t :: %__MODULE__{
            clusters: [DataTransforms.wire_cluster()],
            membership: tuple(),
            cluster_colors: %{DataTransforms.cluster_id() => String.t()},
            name_to_id: %{String.t() => DataTransforms.cluster_id()},
            cluster_names: %{DataTransforms.cluster_id() => String.t()},
            cluster_ids: [DataTransforms.cluster_id()],
            raw_centroids: [
              {DataTransforms.wire_cluster(), %{DataTransforms.dimension() => number()}}
            ],
            iterations: pos_integer() | nil
          }
  end

  defmodule CalendarDay do
    @moduledoc "A single day rendered on the calendar heatmap."

    alias FugueWeb.MoodLive.DataTransforms

    defstruct [:date, :dimensions, :memberships, :is_gap]

    @typedoc "A gap day has no dimensions; its memberships are imputed, or `%{}`."
    @type t :: %__MODULE__{
            date: DataTransforms.iso_date(),
            dimensions: %{DataTransforms.dimension() => float() | nil} | nil,
            memberships: DataTransforms.memberships(),
            is_gap: boolean()
          }
  end

  defmodule GapData do
    @moduledoc "Gap analysis, parsed from `Fugue.Mood.Wire.gaps/2`."

    alias FugueWeb.MoodLive.DataTransforms

    defstruct [:transitions, :length_distribution, :imputed_memberships]

    @typedoc "Still wire-shaped inside: string keys, ISO dates (see `Fugue.Mood.Wire.gaps/2`)."
    @type t :: %__MODULE__{
            transitions: [Fugue.Mood.Wire.json_map()],
            length_distribution: %{String.t() => pos_integer()},
            imputed_memberships: %{DataTransforms.iso_date() => DataTransforms.memberships()}
          }

    @spec from_api(Fugue.Mood.Wire.json_map() | nil) :: t() | nil
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
