defmodule FugueWeb.MoodLive.Snapshot do
  @moduledoc """
  Pure derivation of view-shape data for `/mood`.

  The mood dataset is a snapshot, not a live pipeline (see
  `lib/fugue_web/live/mood_live/CLAUDE.md`). This module materializes
  every figure-shaped collection from a single triple of inputs
  (entries, clustering analysis, and gap analysis) in one pass.

  `from/3` is the only entry point. `@enforce_keys` guarantees the
  constructor populates every field; missing one fails at compile.
  Focus and brush state live elsewhere; Snapshot has no knowledge of
  them.
  """

  alias FugueWeb.MoodLive.{Annotations, DataTransforms}
  alias FugueWeb.MoodLive.DataTransforms, as: DT
  alias FugueWeb.MoodLive.Structs.{AnalysisResult, CalendarDay, GapData}

  @enforce_keys [
    :smoothed_daily,
    :full_date_range,
    :mood_transitions,
    :timeline_segments,
    :stats,
    :cluster_names,
    :trajectory_points,
    :trajectory_annotations,
    :calendar_days,
    :transition_dates,
    :radar_centroids,
    :radar_dimensions,
    :stream_series,
    :mood_flowers_list,
    :flower_dimensions,
    :distribution_points,
    :distribution_clusters,
    :season_months,
    :ambiguity_bins,
    :ambiguity_threshold,
    :drift_dimensions
  ]

  defstruct @enforce_keys

  @type stream_point :: %{date: DT.iso_date(), memberships: DT.memberships()}

  @type distribution_point :: %{
          dimensions: %{DT.dimension() => float() | nil},
          cluster: DT.cluster_id() | nil
        }

  @type distribution_cluster :: %{id: DT.cluster_id(), name: String.t(), color: String.t()}

  @type t :: %__MODULE__{
          smoothed_daily: [DT.daily()],
          full_date_range: %{start: DT.iso_date(), end: DT.iso_date()} | nil,
          mood_transitions: [DT.mood_transition()],
          timeline_segments: [DT.segment()],
          stats: DT.stats(),
          cluster_names: %{DT.cluster_id() => String.t()},
          trajectory_points: [DT.trajectory_point()],
          trajectory_annotations: [Annotations.t()],
          calendar_days: [CalendarDay.t()],
          transition_dates: [DT.iso_date()],
          radar_centroids: [DT.centroid()],
          radar_dimensions: [DT.dimension(), ...],
          stream_series: [stream_point()],
          mood_flowers_list: [DT.mood_flower()],
          flower_dimensions: [DT.dimension(), ...],
          distribution_points: [distribution_point()],
          distribution_clusters: [distribution_cluster()],
          season_months: [DT.season_month(), ...],
          ambiguity_bins: [DT.ambiguity_bin(), ...],
          ambiguity_threshold: float(),
          drift_dimensions: [DT.drift(), ...]
        }

  @spec from([DT.wire_entry()], AnalysisResult.t(), GapData.t() | nil) :: t()
  def from(entries, %AnalysisResult{} = analysis, gaps) do
    smoothed_daily =
      entries
      |> DataTransforms.daily_dominants(analysis)
      |> DataTransforms.smooth_runs()

    mood_transitions = mood_transitions(smoothed_daily)
    dimensions = DataTransforms.dimensions()

    %__MODULE__{
      smoothed_daily: smoothed_daily,
      full_date_range: full_date_range(entries),
      mood_transitions: mood_transitions,
      timeline_segments: DataTransforms.build_segments(smoothed_daily),
      stats:
        DataTransforms.narrative_stats(
          entries,
          analysis,
          smoothed_daily,
          mood_transitions,
          gaps
        ),
      cluster_names: analysis.cluster_names,
      trajectory_points: DataTransforms.build_trajectory(entries, smoothed_daily),
      trajectory_annotations: Annotations.all(),
      calendar_days: DataTransforms.build_calendar_days(entries, analysis, gaps),
      transition_dates: transition_dates(smoothed_daily),
      radar_centroids: DataTransforms.build_centroids(analysis),
      radar_dimensions: dimensions,
      stream_series: stream_series(entries, analysis),
      mood_flowers_list: DataTransforms.build_mood_flowers(entries, smoothed_daily),
      flower_dimensions: dimensions,
      distribution_points: distribution_points(entries, smoothed_daily),
      distribution_clusters: distribution_clusters(analysis),
      season_months: DataTransforms.build_seasonality(smoothed_daily),
      ambiguity_bins: DataTransforms.build_ambiguity_histogram(entries, analysis),
      ambiguity_threshold: 0.45,
      drift_dimensions: DataTransforms.build_drift(entries)
    }
  end

  # --- privates --------------------------------------------------------

  defp full_date_range([]), do: nil

  defp full_date_range(entries) do
    sorted = entries |> Enum.map(& &1["date"]) |> Enum.sort()
    %{start: List.first(sorted), end: List.last(sorted)}
  end

  defp mood_transitions(smoothed_daily) do
    smoothed_daily
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.filter(fn [a, b] -> a.cluster != b.cluster end)
    |> Enum.map(fn [a, b] -> %{date: b.date, from: a.cluster, to: b.cluster} end)
  end

  defp transition_dates(smoothed_daily) do
    smoothed_daily
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.filter(fn [a, b] -> a.cluster != b.cluster end)
    |> Enum.map(fn [_a, b] -> b.date end)
  end

  defp stream_series(entries, %AnalysisResult{} = analysis) do
    entries
    |> Enum.with_index()
    |> Enum.map(fn {entry, idx} ->
      mems =
        DataTransforms.build_memberships(elem(analysis.membership, idx), analysis.clusters)

      %{date: entry["date"], memberships: mems}
    end)
  end

  defp distribution_points(entries, smoothed_daily) do
    cluster_by_date = Map.new(smoothed_daily, fn d -> {d.date, d.cluster} end)

    Enum.map(entries, fn e ->
      %{
        dimensions: e["dimensions"] || %{},
        cluster: Map.get(cluster_by_date, e["date"])
      }
    end)
  end

  defp distribution_clusters(%AnalysisResult{} = analysis) do
    Enum.map(analysis.clusters, fn c ->
      %{
        id: c["id"],
        name: c["name"],
        color: Map.get(analysis.cluster_colors, c["id"], "#666")
      }
    end)
  end
end
