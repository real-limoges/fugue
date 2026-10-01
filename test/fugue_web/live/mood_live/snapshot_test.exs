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
end
