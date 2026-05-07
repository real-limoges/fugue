defmodule FugueWeb.MoodLive.DataTransformsPropertyTest do
  @moduledoc """
  Property-based tests for the pure mood-analysis transforms that the
  visualizations depend on. Focuses on functions whose output shape has
  load-bearing invariants (length preservation, membership-sum budget,
  chronological coverage of segment lists).
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias FugueWeb.MoodLive.DataTransforms

  # --- generators ----------------------------------------------------------

  defp cluster_id_gen, do: StreamData.member_of(["c0", "c1", "c2", "c3"])

  defp cluster_list_gen(min \\ 1, max \\ 4) do
    StreamData.integer(min..max)
    |> StreamData.map(fn n ->
      for i <- 0..(n - 1), do: %{"id" => "c#{i}", "name" => "Cluster #{i}"}
    end)
  end

  # A membership row of length n with values summing approximately to 1.
  # Generates raw non-negative weights, normalizes them, and returns a list.
  defp membership_row_gen(n) do
    StreamData.list_of(StreamData.float(min: 0.0, max: 10.0), length: n)
    |> StreamData.map(fn ws ->
      total = Enum.sum(ws)

      if total <= 0 do
        List.duplicate(1.0 / n, n)
      else
        Enum.map(ws, &(&1 / total))
      end
    end)
  end

  defp daily_day_gen do
    StreamData.tuple({
      StreamData.integer(1..365),
      cluster_id_gen()
    })
  end

  # A chronologically-ordered list of daily {date, cluster} entries starting
  # from 2026-01-01. Day numbers are unique but monotonic isn't important;
  # the caller can sort.
  defp daily_sequence_gen(min_length) do
    StreamData.list_of(daily_day_gen(), min_length: min_length, max_length: 30)
    |> StreamData.map(&to_daily_list/1)
  end

  defp to_daily_list(tuples) do
    tuples
    |> Enum.with_index()
    |> Enum.map(fn {{_day_num, cluster}, idx} ->
      date =
        Date.add(~D[2026-01-01], idx)
        |> Date.to_iso8601()

      %{date: date, cluster: cluster}
    end)
  end

  # --- build_memberships/2 ------------------------------------------------

  describe "build_memberships/2 property" do
    property "returns one key per cluster, in the order the clusters were given" do
      check all(
              clusters <- cluster_list_gen(),
              row <- membership_row_gen(length(clusters))
            ) do
        result = DataTransforms.build_memberships(row, clusters)
        expected_keys = Enum.map(clusters, & &1["id"])

        assert Map.keys(result) |> Enum.sort() == Enum.sort(expected_keys)
      end
    end

    property "values preserve the membership weights positionally" do
      check all(
              clusters <- cluster_list_gen(),
              row <- membership_row_gen(length(clusters))
            ) do
        result = DataTransforms.build_memberships(row, clusters)

        for {cluster, i} <- Enum.with_index(clusters) do
          assert result[cluster["id"]] == Enum.at(row, i)
        end
      end
    end

    property "a tuple row yields the same result as the equivalent list row" do
      check all(
              clusters <- cluster_list_gen(),
              row <- membership_row_gen(length(clusters))
            ) do
        list_result = DataTransforms.build_memberships(row, clusters)
        tuple_result = DataTransforms.build_memberships(List.to_tuple(row), clusters)
        assert list_result == tuple_result
      end
    end

    property "shorter rows zero-fill trailing clusters" do
      check all(
              clusters <- cluster_list_gen(2, 4),
              # Row with one fewer entry than clusters.
              row <- membership_row_gen(length(clusters) - 1)
            ) do
        result = DataTransforms.build_memberships(row, clusters)
        last_cluster = List.last(clusters)["id"]
        assert result[last_cluster] == 0
      end
    end

    property "normalized input sums to approximately 1" do
      check all(
              clusters <- cluster_list_gen(),
              row <- membership_row_gen(length(clusters))
            ) do
        result = DataTransforms.build_memberships(row, clusters)
        sum = result |> Map.values() |> Enum.sum()
        assert_in_delta(sum, 1.0, 0.001)
      end
    end
  end

  # --- build_segments/1 ---------------------------------------------------

  describe "build_segments/1 property" do
    property "empty input yields empty output" do
      check all(_ <- StreamData.constant(nil)) do
        assert DataTransforms.build_segments([]) == []
      end
    end

    property "every segment's cluster matches its source days' cluster" do
      check all(daily <- daily_sequence_gen(1)) do
        segs = DataTransforms.build_segments(daily)
        # For each segment, the corresponding slice of input days must all have
        # the segment's cluster.
        by_date = Map.new(daily, &{&1.date, &1.cluster})

        for seg <- segs do
          range =
            Date.range(
              Date.from_iso8601!(seg.start),
              Date.from_iso8601!(seg.end_date)
            )

          assert Enum.all?(range, fn d -> Map.get(by_date, Date.to_iso8601(d)) == seg.cluster end)
        end
      end
    end

    property "segments cover every input date without gaps or overlap" do
      check all(daily <- daily_sequence_gen(1)) do
        segs = DataTransforms.build_segments(daily)

        covered =
          Enum.flat_map(segs, fn seg ->
            Date.range(
              Date.from_iso8601!(seg.start),
              Date.from_iso8601!(seg.end_date)
            )
            |> Enum.map(&Date.to_iso8601/1)
          end)

        input_dates = Enum.map(daily, & &1.date)
        assert covered == input_dates
      end
    end

    property "adjacent segments always have different clusters" do
      check all(daily <- daily_sequence_gen(2)) do
        segs = DataTransforms.build_segments(daily)

        segs
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.each(fn [a, b] -> assert a.cluster != b.cluster end)
      end
    end

    property "each segment's end_date is >= its start (as ISO dates)" do
      check all(daily <- daily_sequence_gen(1)) do
        for seg <- DataTransforms.build_segments(daily) do
          assert seg.start <= seg.end_date
        end
      end
    end
  end

  # --- smooth_runs/2 ------------------------------------------------------

  describe "smooth_runs/2 property" do
    property "length is preserved -- one output day per input day" do
      check all(
              daily <- daily_sequence_gen(1),
              min <- StreamData.integer(1..10)
            ) do
        smoothed = DataTransforms.smooth_runs(daily, min)
        assert length(smoothed) == length(daily)
      end
    end

    property "dates are preserved in order" do
      check all(
              daily <- daily_sequence_gen(1),
              min <- StreamData.integer(1..10)
            ) do
        smoothed = DataTransforms.smooth_runs(daily, min)
        assert Enum.map(smoothed, & &1.date) == Enum.map(daily, & &1.date)
      end
    end

    property "every output cluster appears somewhere in the input clusters" do
      check all(
              daily <- daily_sequence_gen(1),
              min <- StreamData.integer(1..10)
            ) do
        smoothed = DataTransforms.smooth_runs(daily, min)
        input_clusters = daily |> Enum.map(& &1.cluster) |> Enum.uniq() |> MapSet.new()

        for day <- smoothed do
          assert MapSet.member?(input_clusters, day.cluster)
        end
      end
    end

    property "min_length of 1 is identity (no smoothing)" do
      check all(daily <- daily_sequence_gen(1)) do
        assert DataTransforms.smooth_runs(daily, 1) == daily
      end
    end

    property "after smoothing, every run of the dominant cluster has length >= min_length (except possibly the first)" do
      check all(
              daily <- daily_sequence_gen(2),
              min <- StreamData.integer(2..5)
            ) do
        smoothed = DataTransforms.smooth_runs(daily, min)
        runs = cluster_runs(Enum.map(smoothed, & &1.cluster))

        # The very first run inherits from whatever the first entry was, even
        # if short. Every subsequent run reflects a transition the smoother
        # admitted, so it must be at least `min` long OR be the final run
        # (which inherits whatever state held through to the end).
        [_first | rest] = runs

        case rest do
          [] ->
            :ok

          runs_rest ->
            leading = Enum.drop(runs_rest, -1)
            Enum.each(leading, fn {_cluster, len} -> assert len >= min end)
        end
      end
    end
  end

  # --- helpers -------------------------------------------------------------

  # Collapses [a, a, b, a, a, a] into [{a, 2}, {b, 1}, {a, 3}].
  defp cluster_runs([]), do: []

  defp cluster_runs([h | t]) do
    Enum.reduce(t, [{h, 1}], fn c, [{cur, n} | rest] = acc ->
      if c == cur do
        [{cur, n + 1} | rest]
      else
        [{c, 1} | acc]
      end
    end)
    |> Enum.reverse()
  end
end
