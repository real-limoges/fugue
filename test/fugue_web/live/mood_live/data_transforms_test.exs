defmodule FugueWeb.MoodLive.DataTransformsTest do
  use ExUnit.Case, async: true

  alias FugueWeb.MoodLive.DataTransforms
  alias FugueWeb.MoodLive.Structs.{AnalysisResult, CalendarDay, GapData}

  describe "build_histograms/3" do
    test "returns one entry per canonical dimension" do
      result = DataTransforms.build_histograms([], %{}, 5)

      assert Map.keys(result) |> Enum.sort() ==
               Enum.sort(~w(sleep anxiety sensitivity outlook speed))
    end

    test "empty entries yield zero-count bins with the requested bin count" do
      result = DataTransforms.build_histograms([], %{"sleep" => {0.0, 10.0}}, 4)

      sleep = result["sleep"]
      assert length(sleep) == 4
      assert Enum.all?(sleep, fn bin -> bin.n == 0.0 end)
      assert Enum.at(sleep, 0).x0 == 0.0
      assert Enum.at(sleep, 0).x1 == 2.5
      assert Enum.at(sleep, 3).x1 == 10.0
    end

    test "normalizes counts so the densest bin has n == 1.0" do
      entries =
        for v <- [1.0, 1.0, 1.0, 5.0, 9.0] do
          %{"date" => "2026-01-01", "dimensions" => %{"sleep" => v}}
        end

      result = DataTransforms.build_histograms(entries, %{"sleep" => {0.0, 10.0}}, 10)
      peak = result["sleep"] |> Enum.map(& &1.n) |> Enum.max()

      assert peak == 1.0
    end

    test "clamps values outside bounds to the edge bins" do
      entries = [
        %{"date" => "2026-01-01", "dimensions" => %{"sleep" => -5.0}},
        %{"date" => "2026-01-02", "dimensions" => %{"sleep" => 50.0}}
      ]

      result = DataTransforms.build_histograms(entries, %{"sleep" => {0.0, 10.0}}, 4)

      assert Enum.at(result["sleep"], 0).n > 0
      assert Enum.at(result["sleep"], 3).n > 0
    end

    test "ignores entries missing the dimension" do
      entries = [
        %{"date" => "2026-01-01", "dimensions" => %{"sleep" => 3.0}},
        %{"date" => "2026-01-02", "dimensions" => %{}},
        %{"date" => "2026-01-03", "dimensions" => nil}
      ]

      result = DataTransforms.build_histograms(entries, %{"sleep" => {0.0, 10.0}}, 10)

      total_n = result["sleep"] |> Enum.map(& &1.n) |> Enum.sum()
      assert total_n > 0.0
    end

    test "falls back to default bounds for dimensions not in bounds_by_dim" do
      result = DataTransforms.build_histograms([], %{}, 2)
      anxiety = result["anxiety"]
      assert length(anxiety) == 2
      assert Enum.at(anxiety, 0).x0 == 0.0
      assert Enum.at(anxiety, 1).x1 == 10.0
    end
  end

  describe "parse_analysis/2" do
    test "assigns cluster_N ids in order" do
      raw = %{
        "clusters" => [%{"name" => "a"}, %{"name" => "b"}],
        "membership" => [[1.0, 0.0], [0.0, 1.0]],
        "iterations" => 7
      }

      result = DataTransforms.parse_analysis(raw, fake_entries(2))

      ids = Enum.map(result.clusters, & &1["id"])
      assert ids == ["cluster_0", "cluster_1"]
    end

    test "maps original API names to generated ids in name_to_id" do
      raw = %{
        "clusters" => [%{"name" => "alpha"}, %{"name" => "beta"}],
        "membership" => [[1.0, 0.0]],
        "iterations" => 1
      }

      result = DataTransforms.parse_analysis(raw, fake_entries(1))

      assert result.name_to_id == %{"alpha" => "cluster_0", "beta" => "cluster_1"}
    end

    test "cycles through the color palette when k exceeds palette length" do
      raw = %{
        "clusters" => for(i <- 0..9, do: %{"name" => "c#{i}"}),
        "membership" => [List.duplicate(0.1, 10)],
        "iterations" => 1
      }

      result = DataTransforms.parse_analysis(raw, fake_entries(1))

      assert result.cluster_colors["cluster_0"] == result.cluster_colors["cluster_8"]
    end

    test "overwrites raw cluster names with descriptive generated names" do
      raw = %{
        "clusters" => [
          %{"name" => "raw_0", "centroid" => %{"sleep" => 8.0}},
          %{"name" => "raw_1", "centroid" => %{"sleep" => 2.0}}
        ],
        "membership" => [[0.9, 0.1], [0.1, 0.9]],
        "iterations" => 3
      }

      entries = [
        %{
          "date" => "2026-01-01",
          "dimensions" => %{
            "sleep" => 8.0,
            "anxiety" => 2.0,
            "sensitivity" => 3.0,
            "outlook" => 8.0,
            "speed" => 7.0
          }
        },
        %{
          "date" => "2026-01-02",
          "dimensions" => %{
            "sleep" => 2.0,
            "anxiety" => 7.0,
            "sensitivity" => 8.0,
            "outlook" => 2.0,
            "speed" => 1.0
          }
        }
      ]

      result = DataTransforms.parse_analysis(raw, entries)

      names = Enum.map(result.clusters, & &1["name"])
      refute "raw_0" in names
      refute "raw_1" in names
    end

    test "propagates fpc and iterations" do
      raw = %{
        "clusters" => [%{"name" => "a"}],
        "membership" => [[1.0]],
        "fpc" => 0.87,
        "iterations" => 42
      }

      result = DataTransforms.parse_analysis(raw, fake_entries(1))

      assert result.fpc == 0.87
      assert result.iterations == 42
    end

    test "handles empty clusters" do
      raw = %{"clusters" => [], "membership" => [], "iterations" => 0}
      result = DataTransforms.parse_analysis(raw, [])

      assert result.clusters == []
      assert result.cluster_colors == %{}
      assert result.name_to_id == %{}
    end
  end

  describe "build_memberships/2" do
    test "pairs clusters with row values by position" do
      clusters = [%{"id" => "cluster_0"}, %{"id" => "cluster_1"}]

      assert DataTransforms.build_memberships([0.7, 0.3], clusters) ==
               %{"cluster_0" => 0.7, "cluster_1" => 0.3}
    end

    test "returns empty map for non-list rows" do
      clusters = [%{"id" => "cluster_0"}]
      assert DataTransforms.build_memberships(nil, clusters) == %{}
      assert DataTransforms.build_memberships("not a list", clusters) == %{}
    end

    test "defaults missing row slots to 0" do
      clusters = [%{"id" => "cluster_0"}, %{"id" => "cluster_1"}]

      assert DataTransforms.build_memberships([0.5], clusters) ==
               %{"cluster_0" => 0.5, "cluster_1" => 0}
    end
  end

  describe "daily_dominants/2" do
    test "picks the argmax cluster for each entry" do
      entries = [
        %{"date" => "2026-01-01"},
        %{"date" => "2026-01-02"},
        %{"date" => "2026-01-03"}
      ]

      analysis = %AnalysisResult{
        clusters: [%{"id" => "cluster_0"}, %{"id" => "cluster_1"}],
        membership: {{0.9, 0.1}, {0.2, 0.8}, {0.6, 0.4}}
      }

      result = DataTransforms.daily_dominants(entries, analysis)

      assert Enum.map(result, & &1.cluster) == ["cluster_0", "cluster_1", "cluster_0"]
    end

    test "drops entries without a dominant cluster" do
      entries = [%{"date" => "2026-01-01"}, %{"date" => "2026-01-02"}]

      analysis = %AnalysisResult{
        clusters: [],
        membership: {{}, {}}
      }

      assert DataTransforms.daily_dominants(entries, analysis) == []
    end
  end

  describe "smooth_runs/1" do
    test "short runs are absorbed into the surrounding state" do
      daily = [
        %{date: "1", cluster: "a"},
        %{date: "2", cluster: "a"},
        %{date: "3", cluster: "a"},
        %{date: "4", cluster: "b"},
        %{date: "5", cluster: "b"},
        %{date: "6", cluster: "a"},
        %{date: "7", cluster: "a"},
        %{date: "8", cluster: "a"}
      ]

      result = DataTransforms.smooth_runs(daily)

      assert Enum.map(result, & &1.cluster) == List.duplicate("a", 8)
    end

    test "runs of min_length or more are preserved as transitions" do
      daily =
        for i <- 1..5, do: %{date: "a#{i}", cluster: "a"}

      daily = daily ++ for(i <- 1..5, do: %{date: "b#{i}", cluster: "b"})

      result = DataTransforms.smooth_runs(daily)

      assert Enum.map(result, & &1.cluster) ==
               List.duplicate("a", 5) ++ List.duplicate("b", 5)
    end

    test "empty input returns empty list" do
      assert DataTransforms.smooth_runs([]) == []
    end

    test "min_length <= 1 returns the sequence unchanged" do
      daily = [
        %{date: "1", cluster: "a"},
        %{date: "2", cluster: "b"},
        %{date: "3", cluster: "a"}
      ]

      assert DataTransforms.smooth_runs(daily, 1) == daily
    end

    test "alternating short flips are fully absorbed" do
      daily =
        for i <- 1..8 do
          %{date: "#{i}", cluster: if(rem(i, 2) == 0, do: "b", else: "a")}
        end

      result = DataTransforms.smooth_runs(daily)
      assert Enum.all?(result, fn d -> d.cluster == "a" end)
    end

    test "min_run_length/0 exposes the default" do
      assert DataTransforms.min_run_length() == 5
    end
  end

  describe "build_trajectory/2" do
    test "returns empty list when there are fewer than 2 entries" do
      assert DataTransforms.build_trajectory([], []) == []
      assert DataTransforms.build_trajectory([entry_with_dims()], []) == []
    end

    test "returns one point per entry with date, cluster, x, y" do
      entries = [
        entry_with_dims("2026-01-01", [1.0, 1.0, 1.0, 1.0, 1.0]),
        entry_with_dims("2026-01-02", [9.0, 9.0, 9.0, 9.0, 9.0]),
        entry_with_dims("2026-01-03", [5.0, 5.0, 5.0, 5.0, 5.0])
      ]

      daily = [
        %{date: "2026-01-01", cluster: "cluster_0"},
        %{date: "2026-01-02", cluster: "cluster_1"},
        %{date: "2026-01-03", cluster: "cluster_0"}
      ]

      result = DataTransforms.build_trajectory(entries, daily)

      assert length(result) == 3
      assert Enum.map(result, & &1.date) == ["2026-01-01", "2026-01-02", "2026-01-03"]
      assert Enum.map(result, & &1.cluster) == ["cluster_0", "cluster_1", "cluster_0"]
      assert Enum.all?(result, &is_number(&1.x))
      assert Enum.all?(result, &is_number(&1.y))
    end

    test "points with no matching daily entry have nil cluster" do
      entries = [
        entry_with_dims("2026-01-01", [1.0, 1.0, 1.0, 1.0, 1.0]),
        entry_with_dims("2026-01-02", [5.0, 5.0, 5.0, 5.0, 5.0])
      ]

      result = DataTransforms.build_trajectory(entries, [])
      assert Enum.all?(result, &is_nil(&1.cluster))
    end
  end

  describe "build_calendar_days/3" do
    test "produces a contiguous date range including gap days" do
      entries = [
        entry_with_dims("2026-01-01", [5.0, 5.0, 5.0, 5.0, 5.0]),
        entry_with_dims("2026-01-04", [5.0, 5.0, 5.0, 5.0, 5.0])
      ]

      analysis = %AnalysisResult{
        clusters: [%{"id" => "cluster_0"}],
        membership: {{1.0}, {1.0}}
      }

      gaps = %GapData{
        transitions: [],
        length_distribution: %{},
        imputed_memberships: %{"2026-01-02" => %{"cluster_0" => 1.0}}
      }

      days = DataTransforms.build_calendar_days(entries, analysis, gaps)

      assert Enum.map(days, & &1.date) == [
               "2026-01-01",
               "2026-01-02",
               "2026-01-03",
               "2026-01-04"
             ]

      assert [%CalendarDay{is_gap: false} | _] = days
    end

    test "marks days without entries as gap days" do
      entries = [
        entry_with_dims("2026-01-01", [5.0, 5.0, 5.0, 5.0, 5.0]),
        entry_with_dims("2026-01-03", [5.0, 5.0, 5.0, 5.0, 5.0])
      ]

      analysis = %AnalysisResult{
        clusters: [%{"id" => "cluster_0"}],
        membership: {{1.0}, {1.0}}
      }

      days = DataTransforms.build_calendar_days(entries, analysis, nil)

      gap_day = Enum.find(days, fn d -> d.date == "2026-01-02" end)
      assert gap_day.is_gap == true
      assert gap_day.dimensions == nil
    end

    test "empty entries yield empty days" do
      analysis = %AnalysisResult{clusters: [], membership: {}}
      assert DataTransforms.build_calendar_days([], analysis, nil) == []
    end
  end

  describe "remap_gap_keys/2" do
    test "rewrites transition before/after map keys via mapping" do
      gaps = %GapData{
        transitions: [%{"before" => %{"raw_0" => 0.7}, "after" => %{"raw_1" => 0.9}}],
        length_distribution: %{},
        imputed_memberships: %{}
      }

      result =
        DataTransforms.remap_gap_keys(gaps, %{"raw_0" => "cluster_0", "raw_1" => "cluster_1"})

      [t] = result.transitions
      assert t["before"] == %{"cluster_0" => 0.7}
      assert t["after"] == %{"cluster_1" => 0.9}
    end

    test "rewrites imputed_memberships keys by date preserved" do
      gaps = %GapData{
        transitions: [],
        length_distribution: %{},
        imputed_memberships: %{"2026-01-02" => %{"raw_0" => 0.6, "raw_1" => 0.4}}
      }

      result =
        DataTransforms.remap_gap_keys(gaps, %{"raw_0" => "cluster_0", "raw_1" => "cluster_1"})

      assert result.imputed_memberships == %{
               "2026-01-02" => %{"cluster_0" => 0.6, "cluster_1" => 0.4}
             }
    end

    test "keys missing from mapping survive unchanged" do
      gaps = %GapData{
        transitions: [%{"before" => %{"unknown" => 0.5}, "after" => %{}}],
        length_distribution: %{},
        imputed_memberships: %{}
      }

      result = DataTransforms.remap_gap_keys(gaps, %{"raw_0" => "cluster_0"})
      [t] = result.transitions
      assert t["before"] == %{"unknown" => 0.5}
    end

    test "returns nil for nil input" do
      assert DataTransforms.remap_gap_keys(nil, %{}) == nil
    end
  end

  describe "build_segments/1" do
    test "collapses contiguous same-cluster days into one segment" do
      daily = [
        %{date: "2026-01-01", cluster: "a"},
        %{date: "2026-01-02", cluster: "a"},
        %{date: "2026-01-03", cluster: "b"},
        %{date: "2026-01-04", cluster: "b"},
        %{date: "2026-01-05", cluster: "a"}
      ]

      result = DataTransforms.build_segments(daily)

      assert [
               %{start: "2026-01-01", end_date: "2026-01-02", cluster: "a"},
               %{start: "2026-01-03", end_date: "2026-01-04", cluster: "b"},
               %{start: "2026-01-05", end_date: "2026-01-05", cluster: "a"}
             ] = result
    end

    test "empty input returns empty list" do
      assert DataTransforms.build_segments([]) == []
    end
  end

  # -- helpers --

  defp fake_entries(n) do
    for i <- 1..n do
      %{
        "date" => "2026-01-0#{i}",
        "dimensions" => %{
          "sleep" => 5.0,
          "anxiety" => 5.0,
          "sensitivity" => 5.0,
          "outlook" => 5.0,
          "speed" => 5.0
        }
      }
    end
  end

  defp entry_with_dims(date \\ "2026-01-01", dims \\ [5.0, 5.0, 5.0, 5.0, 5.0]) do
    [s, a, se, o, sp] = dims

    %{
      "date" => date,
      "dimensions" => %{
        "sleep" => s,
        "anxiety" => a,
        "sensitivity" => se,
        "outlook" => o,
        "speed" => sp
      }
    }
  end
end
