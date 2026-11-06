defmodule FugueWeb.MoodLive.SnapshotTest do
  use ExUnit.Case, async: true

  alias Fugue.Mood.Wire
  alias FugueWeb.MoodLive.{DataTransforms, Snapshot}
  alias FugueWeb.MoodLive.Structs.GapData

  # Built the way MoodLive builds it, over a six-month window so it stays fast.
  setup_all do
    {from, to} = {~D[2022-04-01], ~D[2022-09-30]}
    {:ok, entries} = Wire.data(from, to)
    {:ok, raw_analysis} = Wire.cluster(3, 1.5, from, to)
    {:ok, raw_gaps} = Wire.gaps(from, to)

    analysis = DataTransforms.parse_analysis(raw_analysis, entries)
    gaps = raw_gaps |> GapData.from_api() |> DataTransforms.remap_gap_keys(analysis.name_to_id)

    %{entries: entries, snapshot: Snapshot.from(entries, analysis, gaps)}
  end

  test "has one smoothed day per entry, in order", %{entries: entries, snapshot: snapshot} do
    assert Enum.map(snapshot.smoothed_daily, & &1.date) == Enum.map(entries, & &1["date"])
  end

  test "spans the entries' first and last dates", %{entries: entries, snapshot: snapshot} do
    assert snapshot.full_date_range == %{
             start: hd(entries)["date"],
             end: List.last(entries)["date"]
           }
  end

  test "has one transition between each pair of timeline segments", %{snapshot: snapshot} do
    segments = snapshot.timeline_segments
    transitions = snapshot.mood_transitions

    assert length(transitions) == length(segments) - 1
    assert snapshot.transition_dates == Enum.map(transitions, & &1.date)

    for {transition, [before, next]} <- Enum.zip(transitions, Enum.chunk_every(segments, 2, 1)) do
      assert transition.from == before.cluster
      assert transition.to == next.cluster
      assert transition.date == next.start
    end
  end

  test "names every mood dimension for the radar and the flowers", %{snapshot: snapshot} do
    assert snapshot.radar_dimensions == DataTransforms.dimensions()
    assert snapshot.flower_dimensions == DataTransforms.dimensions()
  end

  # Dialyzer cannot see field types inside a list of maps (an Enum.map result
  # overlaps any list type through the empty list), so the @type shapes in
  # DataTransforms and Snapshot are checked here instead: every element of
  # every collection must carry exactly the keys its type names. Keep these
  # lists in step with the @type definitions.
  @collection_keys %{
    smoothed_daily: [:cluster, :date],
    mood_transitions: [:date, :from, :to],
    timeline_segments: [:cluster, :end_date, :start],
    trajectory_points: [:cluster, :date, :x, :y],
    radar_centroids: [:id, :name, :values],
    stream_series: [:date, :memberships],
    mood_flowers_list: [:cluster, :count, :month, :raw, :values],
    distribution_points: [:cluster, :dimensions],
    distribution_clusters: [:color, :id, :name],
    season_months: [:counts, :month, :total],
    ambiguity_bins: [:count, :x0, :x1],
    drift_dimensions: [:dimension, :series]
  }

  for {field, keys} <- @collection_keys do
    test "every #{field} element has exactly the keys #{inspect(keys)}", %{snapshot: snapshot} do
      collection = Map.fetch!(snapshot, unquote(field))
      assert collection != [], "#{unquote(field)} is empty, so its shape went unchecked"

      for element <- collection do
        assert element |> Map.keys() |> Enum.sort() == unquote(keys)
      end
    end
  end

  test "stats carries exactly the keys DataTransforms.stats/0 names", %{snapshot: snapshot} do
    assert snapshot.stats |> Map.keys() |> Enum.sort() ==
             Enum.sort([
               :entry_count,
               :date_range,
               :cluster_count,
               :transition_count,
               :most_common,
               :gap_count,
               :longest_run,
               :first_state,
               :last_state,
               :biggest_flow,
               :ambiguity
             ])
  end
end
