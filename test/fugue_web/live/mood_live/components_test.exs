defmodule FugueWeb.MoodLive.ComponentsTest do
  @moduledoc """
  Per-module render tests for the ported Phoenix components. Each block
  invokes the component directly via `render_component/1` with hand-shaped
  fixtures so failures pinpoint the component, not the whole LiveView.

  Integration coverage (the full /mood and /menagerie/fuzzy LiveView render)
  lives in the `FugueWeb.MoodLiveTest` and `FugueWeb.MenagerieLiveTest` files.
  """

  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias FugueWeb.MoodLive.{
    AmbiguityHistogram,
    CalendarGrid,
    ClusterRadar,
    DimensionDistributions,
    DimensionDrift,
    ExperiencePanel,
    GapBreathTimeline,
    MoodFlowers,
    MoodTrajectory,
    SeasonRing,
    StreamGraph,
    TransitionSankey,
    TransitionTimeline
  }

  alias FugueWeb.MoodLive.Structs.CalendarDay

  @colors %{"c0" => "#ff0000", "c1" => "#00ff00", "c2" => "#0000ff"}
  @names %{"c0" => "Red", "c1" => "Green", "c2" => "Blue"}

  # --- ExperiencePanel -----------------------------------------------------

  describe "ExperiencePanel.ambient/1" do
    test "renders with transparent background when nothing is selected" do
      html =
        render_component(&ExperiencePanel.ambient/1,
          selected_day: nil,
          selected_cluster: nil,
          cluster_colors: @colors
        )

      assert html =~ "mood-ambient"
      assert html =~ "opacity: 0"
      assert html =~ "background: transparent"
    end

    test "renders a radial gradient using the dominant cluster color" do
      day = %{
        date: "2026-01-01",
        dominant: %{id: "c0", name: "Red", weight: 0.9},
        cluster_colors: @colors
      }

      html =
        render_component(&ExperiencePanel.ambient/1,
          selected_day: day,
          selected_cluster: nil,
          cluster_colors: @colors
        )

      assert html =~ "opacity: 1"
      assert html =~ "radial-gradient"
      assert html =~ "#ff0000"
    end

    test "falls back to selected_cluster when no day is selected" do
      html =
        render_component(&ExperiencePanel.ambient/1,
          selected_day: nil,
          selected_cluster: "c1",
          cluster_colors: @colors
        )

      assert html =~ "#00ff00"
      assert html =~ "opacity: 1"
    end
  end

  describe "ExperiencePanel.panel/1" do
    test "renders off-screen when no day is selected" do
      html = render_component(&ExperiencePanel.panel/1, selected_day: nil)
      assert html =~ "right: -380px"
      refute html =~ "phx-click=\"clear_highlights\""
    end

    test "renders day content with a close button, dominant cluster, and dimension bars" do
      day = %{
        date: "2026-01-05",
        dominant: %{id: "c0", name: "Red", weight: 0.87},
        memberships: [%{id: "c0", name: "Red", weight: 0.87}],
        dimensions: %{"sleep" => 6.5, "anxiety" => 2.0},
        prev: nil,
        next: nil,
        cluster_colors: @colors
      }

      html = render_component(&ExperiencePanel.panel/1, selected_day: day)

      assert html =~ "right: 0px"
      assert html =~ "phx-click=\"clear_highlights\""
      assert html =~ "2026-01-05"
      assert html =~ "Red"
      assert html =~ "87% membership"
      assert html =~ "sleep"
      assert html =~ "anxiety"
    end

    test "renders prev/next neighbors when present" do
      day = %{
        date: "2026-01-05",
        dominant: nil,
        memberships: [],
        dimensions: %{},
        prev: %{date: "2026-01-04", dominant_id: "c0", dominant_name: "Red"},
        next: %{date: "2026-01-06", dominant_id: "c1", dominant_name: "Green"},
        cluster_colors: @colors
      }

      html = render_component(&ExperiencePanel.panel/1, selected_day: day)

      assert html =~ "Neighbors"
      assert html =~ "2026-01-04"
      assert html =~ "2026-01-06"
      assert html =~ ~s(phx-click="day_selected")
    end
  end

  # --- CalendarGrid --------------------------------------------------------

  describe "CalendarGrid.grid/1" do
    test "empty days renders without crashing" do
      html = render_component(&CalendarGrid.grid/1, days: [], cluster_colors: @colors)
      assert html =~ ~s(id="calendar-heatmap")
      refute html =~ ~s|class="day-cell|
    end

    test "renders one rect per day with data-date + tooltip JSON" do
      days = [
        %CalendarDay{
          date: "2026-01-01",
          dimensions: %{"sleep" => 6},
          memberships: %{"c0" => 0.9, "c1" => 0.1},
          is_gap: false
        },
        %CalendarDay{
          date: "2026-01-02",
          dimensions: %{"sleep" => 7},
          memberships: %{"c0" => 0.8, "c1" => 0.2},
          is_gap: false
        }
      ]

      html =
        render_component(&CalendarGrid.grid/1,
          days: days,
          cluster_colors: @colors,
          cluster_names: @names
        )

      assert html =~ ~s(data-date="2026-01-01")
      assert html =~ ~s(data-date="2026-01-02")
      # data-tooltip carries server-rendered HTML; the hook only positions it.
      assert html =~ "data-tooltip="
      assert html =~ ~s(phx-click="day_selected")
    end

    test "applies the `highlighted` class to cells in highlighted_dates" do
      days = [
        %CalendarDay{
          date: "2026-01-01",
          dimensions: %{},
          memberships: %{"c0" => 0.9},
          is_gap: false
        },
        %CalendarDay{
          date: "2026-01-02",
          dimensions: %{},
          memberships: %{"c0" => 0.9},
          is_gap: false
        }
      ]

      html =
        render_component(&CalendarGrid.grid/1,
          days: days,
          cluster_colors: @colors,
          highlighted_dates: ["2026-01-02"]
        )

      assert html =~ "has-highlight"
      # Parent svg picks up the global state class.
      assert html =~ ~s|class="day-cell highlighted"|
    end

    test "gap cells get `is-gap` class and dashed stroke" do
      days = [
        %CalendarDay{date: "2026-01-10", dimensions: nil, memberships: %{}, is_gap: true}
      ]

      html = render_component(&CalendarGrid.grid/1, days: days, cluster_colors: @colors)

      assert html =~ "is-gap"
      assert html =~ "stroke-dasharray=\"2,1\""
    end

    test "selected_cluster puts `matches-cluster` on days with strong membership" do
      days = [
        %CalendarDay{
          date: "2026-01-01",
          dimensions: %{},
          memberships: %{"c0" => 0.8, "c1" => 0.2},
          is_gap: false
        },
        %CalendarDay{
          date: "2026-01-02",
          dimensions: %{},
          memberships: %{"c0" => 0.1, "c1" => 0.9},
          is_gap: false
        }
      ]

      html =
        render_component(&CalendarGrid.grid/1,
          days: days,
          cluster_colors: @colors,
          selected_cluster: "c1"
        )

      assert html =~ "has-cluster-isolate"
      assert html =~ "matches-cluster"
    end
  end

  # --- StreamGraph ---------------------------------------------------------

  describe "StreamGraph.stream/1" do
    test "empty series renders the svg with no layers" do
      html =
        render_component(&StreamGraph.stream/1,
          series: [],
          cluster_ids: [],
          cluster_colors: %{},
          cluster_names: %{}
        )

      assert html =~ "stream-svg"
      refute html =~ ~s|class="stream-layer|
    end

    test "renders one stream-layer per cluster and a legend item per cluster" do
      series = [
        %{date: "2026-01-01", memberships: %{"c0" => 0.7, "c1" => 0.2, "c2" => 0.1}},
        %{date: "2026-01-02", memberships: %{"c0" => 0.4, "c1" => 0.3, "c2" => 0.3}},
        %{date: "2026-01-03", memberships: %{"c0" => 0.2, "c1" => 0.5, "c2" => 0.3}},
        %{date: "2026-01-04", memberships: %{"c0" => 0.1, "c1" => 0.7, "c2" => 0.2}}
      ]

      html =
        render_component(&StreamGraph.stream/1,
          series: series,
          cluster_ids: ["c0", "c1", "c2"],
          cluster_colors: @colors,
          cluster_names: @names
        )

      assert Regex.scan(~r/<path class="stream-layer/, html) |> length() == 3
      assert html =~ "Red"
      assert html =~ "Green"
      assert html =~ "Blue"
      # Basis-spline paths contain cubic beziers.
      assert html =~ "C"
    end

    test "selected_cluster marks one layer `highlight` and the rest `dim`" do
      series = [
        %{date: "2026-01-01", memberships: %{"c0" => 0.8, "c1" => 0.2}},
        %{date: "2026-01-02", memberships: %{"c0" => 0.7, "c1" => 0.3}},
        %{date: "2026-01-03", memberships: %{"c0" => 0.6, "c1" => 0.4}}
      ]

      html =
        render_component(&StreamGraph.stream/1,
          series: series,
          cluster_ids: ["c0", "c1"],
          cluster_colors: @colors,
          cluster_names: @names,
          selected_cluster: "c0"
        )

      assert html =~ "has-cluster-isolate"
      assert html =~ "stream-layer highlight"
      assert html =~ "stream-layer dim"
    end

    test "selected_day renders a tether line and toggles the parent class" do
      series = [
        %{date: "2026-01-01", memberships: %{"c0" => 1.0}},
        %{date: "2026-01-02", memberships: %{"c0" => 1.0}}
      ]

      html =
        render_component(&StreamGraph.stream/1,
          series: series,
          cluster_ids: ["c0"],
          cluster_colors: @colors,
          cluster_names: @names,
          selected_day: %{date: "2026-01-01"}
        )

      assert html =~ "has-day-focus"
      assert html =~ "tether-line"
    end
  end

  # --- ClusterRadar --------------------------------------------------------

  describe "ClusterRadar.radars/1" do
    test "empty centroids renders no radar cells" do
      html =
        render_component(&ClusterRadar.radars/1,
          centroids: [],
          dimensions: [],
          cluster_colors: %{}
        )

      assert html =~ ~s(class="radar-grid")
      refute html =~ ~s|class="radar-cell|
    end

    test "renders one radar-cell per centroid with grid rings and data polygon" do
      centroids = [
        %{id: "c0", name: "Red", values: %{"sleep" => 0.8, "anxiety" => 0.2}},
        %{id: "c1", name: "Green", values: %{"sleep" => 0.3, "anxiety" => 0.9}}
      ]

      html =
        render_component(&ClusterRadar.radars/1,
          centroids: centroids,
          dimensions: ["sleep", "anxiety"],
          cluster_colors: @colors
        )

      assert Regex.scan(~r/class="radar-cell/, html) |> length() == 2
      # 4 concentric grid rings + 1 outer per cell (at least 4).
      assert length(Regex.scan(~r/<circle r="[^"]+" fill="none"/, html)) >= 4
      # Data polygon.
      assert html =~ "<polygon"
      assert html =~ "phx-click=\"cluster_selected\""
    end

    test "selected_cluster dims non-matching cells" do
      centroids = [
        %{id: "c0", name: "Red", values: %{"sleep" => 0.5}},
        %{id: "c1", name: "Green", values: %{"sleep" => 0.5}}
      ]

      html =
        render_component(&ClusterRadar.radars/1,
          centroids: centroids,
          dimensions: ["sleep"],
          cluster_colors: @colors,
          selected_cluster: "c0"
        )

      assert html =~ ~s|class="radar-cell dim"|
      # The selected cell keeps the plain class (no dim suffix).
      assert html =~ ~s|class="radar-cell"|
    end
  end

  # --- AmbiguityHistogram --------------------------------------------------

  describe "AmbiguityHistogram.histogram/1" do
    test "empty bins renders the shell without crashing" do
      html = render_component(&AmbiguityHistogram.histogram/1, bins: [], threshold: 0.45)
      assert html =~ ~s(id="ambiguity-histogram")
    end

    test "renders one bar per bin and a threshold line with legend labels" do
      bins = [
        %{x0: 0.0, x1: 0.25, count: 3},
        %{x0: 0.25, x1: 0.5, count: 7},
        %{x0: 0.5, x1: 0.75, count: 15},
        %{x0: 0.75, x1: 1.0, count: 9}
      ]

      html = render_component(&AmbiguityHistogram.histogram/1, bins: bins, threshold: 0.45)

      assert html =~ "in-between"
      assert html =~ "decisive"
      # Threshold line stroke color appears multiple times (background, bar, line).
      assert html =~ "#e6a542"
      # Should have visible tick labels like "0%", "100%".
      assert html =~ "0%"
      assert html =~ "100%"
    end
  end

  # --- TransitionTimeline --------------------------------------------------

  describe "TransitionTimeline.timeline/1" do
    test "empty segments renders the shell" do
      html =
        render_component(&TransitionTimeline.timeline/1,
          segments: [],
          transitions: [],
          cluster_colors: @colors
        )

      assert html =~ ~s(id="transition-timeline")
      refute html =~ ~s|class="tl-segment|
    end

    test "renders a clickable rect per segment and a marker per transition" do
      segments = [
        %{cluster: "c0", start: "2026-01-01", end_date: "2026-01-07"},
        %{cluster: "c1", start: "2026-01-08", end_date: "2026-01-14"}
      ]

      transitions = [%{date: "2026-01-08", from: "c0", to: "c1"}]

      html =
        render_component(&TransitionTimeline.timeline/1,
          segments: segments,
          transitions: transitions,
          cluster_colors: @colors
        )

      assert Regex.scan(~r/class="tl-segment/, html) |> length() == 2
      assert html =~ ~s(phx-click="cluster_selected")
      assert html =~ "#fff"
    end

    test "selected_cluster highlights the matching segment class" do
      segments = [
        %{cluster: "c0", start: "2026-01-01", end_date: "2026-01-07"},
        %{cluster: "c1", start: "2026-01-08", end_date: "2026-01-14"}
      ]

      html =
        render_component(&TransitionTimeline.timeline/1,
          segments: segments,
          transitions: [],
          cluster_colors: @colors,
          selected_cluster: "c0"
        )

      assert html =~ "tl-segment highlight"
      assert html =~ "tl-segment dim"
    end
  end

  # --- TransitionSankey ----------------------------------------------------

  describe "TransitionSankey.sankey/1" do
    test "empty transitions renders the shell without labels" do
      html =
        render_component(&TransitionSankey.sankey/1,
          transitions: [],
          cluster_ids: ["c0", "c1"],
          cluster_colors: @colors,
          cluster_names: @names
        )

      refute html =~ ~r/>\s*from\s*</
      refute html =~ ~r/>\s*to\s*</
    end

    test "renders from/to axis labels + node rects + link paths" do
      transitions = [
        %{date: "2026-01-08", from: "c0", to: "c1"},
        %{date: "2026-01-15", from: "c1", to: "c2"},
        %{date: "2026-01-22", from: "c0", to: "c2"}
      ]

      html =
        render_component(&TransitionSankey.sankey/1,
          transitions: transitions,
          cluster_ids: ["c0", "c1", "c2"],
          cluster_colors: @colors,
          cluster_names: @names
        )

      assert html =~ ~r/>\s*from\s*</
      assert html =~ ~r/>\s*to\s*</
      assert html =~ "sankey-link"
      assert html =~ "sankey-node"
      assert html =~ "Red"
      assert html =~ "Green"
      assert html =~ "Blue"
    end

    test "selected_cluster tags links with highlight/dim classes" do
      transitions = [
        %{date: "2026-01-08", from: "c0", to: "c1"},
        %{date: "2026-01-15", from: "c1", to: "c2"}
      ]

      html =
        render_component(&TransitionSankey.sankey/1,
          transitions: transitions,
          cluster_ids: ["c0", "c1", "c2"],
          cluster_colors: @colors,
          cluster_names: @names,
          selected_cluster: "c0"
        )

      assert html =~ "sankey-link highlight"
      assert html =~ "sankey-link dim"
    end
  end

  # --- SeasonRing ----------------------------------------------------------

  describe "SeasonRing.ring/1" do
    test "empty months renders the shell with month labels and ref rings" do
      html =
        render_component(&SeasonRing.ring/1,
          months: [],
          cluster_ids: [],
          cluster_names: %{},
          cluster_colors: %{}
        )

      assert html =~ ~s(id="season-ring")
      # Ref rings render even without data.
      assert html =~ ~s(fill="none")
    end

    test "every populated month emits an annular `A`-arc path per cluster slice" do
      months = for _ <- 0..11, do: %{total: 10, counts: %{"c0" => 6, "c1" => 4}}

      html =
        render_component(&SeasonRing.ring/1,
          months: months,
          cluster_ids: ["c0", "c1"],
          cluster_names: @names,
          cluster_colors: @colors
        )

      # SVG native elliptical-arc command.
      assert html =~ " A"
      assert html =~ "season-arc"
      # All 12 month labels.
      for m <- ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec) do
        assert html =~ m
      end
    end

    test "empty months get a dashed placeholder path" do
      months = for _ <- 0..11, do: %{total: 0, counts: %{}}

      html =
        render_component(&SeasonRing.ring/1,
          months: months,
          cluster_ids: ["c0"],
          cluster_names: @names,
          cluster_colors: @colors
        )

      assert html =~ ~s|stroke-dasharray="2,2"|
      refute html =~ ~s|class="season-arc|
    end
  end

  # --- DimensionDrift ------------------------------------------------------

  describe "DimensionDrift.drift/1" do
    test "empty dimensions renders the svg shell" do
      html = render_component(&DimensionDrift.drift/1, dimensions: [])
      assert html =~ ~s(id="dimension-drift")
    end

    test "renders one row path per dimension with per-row labels" do
      series = for i <- 0..9, do: %{date: "2026-01-#{pad(i + 1)}", value: i * 1.0}

      dims = [
        %{dimension: "sleep", series: series},
        %{dimension: "anxiety", series: series}
      ]

      html = render_component(&DimensionDrift.drift/1, dimensions: dims)

      assert html =~ ~r/>\s*sleep\s*</
      assert html =~ ~r/>\s*anxiety\s*</
      # Basis-spline paths.
      assert html =~ "C"
      # First/last value annotations.
      assert html =~ "0.0"
      assert html =~ "9.0"
    end
  end

  # --- MoodFlowers ---------------------------------------------------------

  describe "MoodFlowers.flowers/1" do
    test "empty flowers renders only the header row" do
      html =
        render_component(&MoodFlowers.flowers/1,
          flowers: [],
          dimensions: ["sleep"],
          cluster_colors: @colors,
          cluster_names: @names
        )

      assert html =~ "Jan"
      assert html =~ "Dec"
      refute html =~ ~s|class="flower-cell|
    end

    test "renders a 12-cell row per year with present/empty flowers" do
      flowers = [
        %{
          month: "2026-01",
          cluster: "c0",
          values: %{"sleep" => 0.6, "anxiety" => 0.3},
          raw: %{"sleep" => 6.0, "anxiety" => 3.0},
          count: 20
        },
        %{
          month: "2026-03",
          cluster: "c1",
          values: %{"sleep" => 0.4, "anxiety" => 0.7},
          raw: %{"sleep" => 4.0, "anxiety" => 7.0},
          count: 15
        }
      ]

      html =
        render_component(&MoodFlowers.flowers/1,
          flowers: flowers,
          dimensions: ["sleep", "anxiety"],
          cluster_colors: @colors,
          cluster_names: @names
        )

      assert html =~ ">2026<"
      # 12 cells total per year.
      assert Regex.scan(~r/data-month="2026-/, html) |> length() == 12
      # Two present flowers and 10 empty dashed placeholders.
      assert html =~ "mood-flower-empty"
      # Cardinal spline output.
      assert html =~ "C"
    end

    test "selected_day focuses the matching month flower" do
      flowers = [
        %{
          month: "2026-02",
          cluster: "c0",
          values: %{"sleep" => 0.5},
          raw: %{"sleep" => 5.0},
          count: 10
        }
      ]

      html =
        render_component(&MoodFlowers.flowers/1,
          flowers: flowers,
          dimensions: ["sleep"],
          cluster_colors: @colors,
          cluster_names: @names,
          selected_day: %{date: "2026-02-10"}
        )

      assert html =~ "flower-cell focused"
    end
  end

  # --- DimensionDistributions ---------------------------------------------

  describe "DimensionDistributions.distributions/1" do
    test "empty dimensions renders the shell" do
      html =
        render_component(&DimensionDistributions.distributions/1,
          points: [],
          dimensions: [],
          clusters: []
        )

      assert html =~ ~s(id="dimension-distributions")
    end

    test "renders a row per dimension with overall dashed + per-cluster filled curves" do
      points = [
        %{dimensions: %{"sleep" => 6}, cluster: "c0"},
        %{dimensions: %{"sleep" => 7}, cluster: "c0"},
        %{dimensions: %{"sleep" => 4}, cluster: "c1"},
        %{dimensions: %{"sleep" => 3}, cluster: "c1"}
      ]

      clusters = [
        %{id: "c0", name: "Red", color: "#ff0000"},
        %{id: "c1", name: "Green", color: "#00ff00"}
      ]

      html =
        render_component(&DimensionDistributions.distributions/1,
          points: points,
          dimensions: ["sleep"],
          clusters: clusters
        )

      assert html =~ ~r/>\s*sleep\s*</
      # Overall curve: dashed outline.
      assert html =~ ~s|stroke-dasharray="2 3"|
      # Per-cluster filled areas — one per cluster.
      assert html =~ "#ff0000"
      assert html =~ "#00ff00"
      # Tick labels rendered for sleep's 0-15 scale.
      assert html =~ ~r/>\s*15\s*</
    end
  end

  # --- GapBreathTimeline ---------------------------------------------------

  describe "GapBreathTimeline.timeline/1" do
    test "nil date_range renders a minimal empty node" do
      html = render_component(&GapBreathTimeline.timeline/1, date_range: nil)
      assert html =~ ~s(id="gap-breath-timeline")
      refute html =~ "class=\"breath\""
    end

    test "no transitions displays the 'no gaps in range' label" do
      html =
        render_component(&GapBreathTimeline.timeline/1,
          date_range: %{start: "2026-01-01", end: "2026-01-31"},
          transitions: [],
          imputed_memberships: %{},
          cluster_colors: @colors,
          cluster_names: @names
        )

      assert html =~ "no gaps in range"
    end

    test "renders one clickable breath path per gap with tooltip + phx-value" do
      transitions = [
        %{
          "gap" => %{"start" => "2026-01-10", "length" => 3},
          "before" => %{"c0" => 0.8, "c1" => 0.2}
        }
      ]

      imputed = %{
        "2026-01-10" => %{"c0" => 0.7, "c1" => 0.3},
        "2026-01-11" => %{"c0" => 0.5, "c1" => 0.5},
        "2026-01-12" => %{"c0" => 0.3, "c1" => 0.7}
      }

      html =
        render_component(&GapBreathTimeline.timeline/1,
          date_range: %{start: "2026-01-01", end: "2026-01-31"},
          transitions: transitions,
          imputed_memberships: imputed,
          cluster_colors: @colors,
          cluster_names: @names
        )

      assert html =~ ~s(class="breath")
      assert html =~ ~s(phx-click="gap_selected")
      assert html =~ ~s(phx-value-start="2026-01-10")
      assert html =~ ~s(phx-value-length="3")
      assert html =~ "data-tooltip="
    end
  end

  # --- MoodTrajectory ------------------------------------------------------

  describe "MoodTrajectory.trajectory/1" do
    test "fewer than 2 points renders an empty shell" do
      html =
        render_component(&MoodTrajectory.trajectory/1,
          points: [%{date: "2026-01-01", x: 0, y: 0, cluster: "c0"}],
          annotations: [],
          cluster_colors: @colors,
          cluster_names: @names
        )

      refute html =~ "<line "
      refute html =~ "class=\"traj-hit\""
    end

    test "renders line segments + dots + hit targets for each day" do
      points = [
        %{date: "2026-01-01", x: 0.0, y: 0.0, cluster: "c0"},
        %{date: "2026-01-02", x: 1.0, y: 1.0, cluster: "c0"},
        %{date: "2026-01-03", x: 2.0, y: 1.5, cluster: "c1"}
      ]

      html =
        render_component(&MoodTrajectory.trajectory/1,
          points: points,
          annotations: [],
          cluster_colors: @colors,
          cluster_names: @names
        )

      # 2 line segments between 3 points.
      assert length(Regex.scan(~r/<line /, html)) >= 2
      # traj-hit hit targets = one per point.
      assert length(Regex.scan(~r/class="traj-hit"/, html)) == 3
      assert html =~ ~s(phx-click="day_selected")
    end

    test "selected_day focuses the matching dot with a white stroke" do
      points = [
        %{date: "2026-01-01", x: 0.0, y: 0.0, cluster: "c0"},
        %{date: "2026-01-02", x: 1.0, y: 1.0, cluster: "c0"}
      ]

      html =
        render_component(&MoodTrajectory.trajectory/1,
          points: points,
          annotations: [],
          cluster_colors: @colors,
          cluster_names: @names,
          selected_day: %{date: "2026-01-02"}
        )

      # Focused dot gets r=5 + stroke=white; others get r=2.2 + stroke=none.
      assert html =~ ~s(r="5")
      assert html =~ ~s(stroke="#fff")
    end

    test "annotations render with label text + leader line + marker ring" do
      points = [
        %{date: "2026-01-01", x: 0.0, y: 0.0, cluster: "c0"},
        %{date: "2026-01-02", x: 1.0, y: 1.0, cluster: "c0"}
      ]

      annotations = [%{date: "2026-01-02", label: "milestone", note: "a note"}]

      html =
        render_component(&MoodTrajectory.trajectory/1,
          points: points,
          annotations: annotations,
          cluster_colors: @colors,
          cluster_names: @names
        )

      assert html =~ "milestone"
      assert html =~ "trajectory-annotations"
      assert html =~ ~s(paint-order="stroke")
    end
  end

  # --- helpers -------------------------------------------------------------

  defp pad(n) when n < 10, do: "0#{n}"
  defp pad(n), do: "#{n}"
end
