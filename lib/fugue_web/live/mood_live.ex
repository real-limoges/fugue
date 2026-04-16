defmodule FugueWeb.MoodLive do
  @moduledoc "Mood journal explorer — fuzzy-clustering visualization of daily mood entries."

  use FugueWeb, :live_view

  alias FugueWeb.MoodLive.{Annotations, DataTransforms, Sections}
  alias FugueWeb.MoodLive.Structs.{AnalysisResult, CalendarDay, GapData}
  alias Fugue.Ish

  @default_k 3
  @default_m 1.5

  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        loading: true,
        error: nil,
        entries: [],
        analysis: %AnalysisResult{
          clusters: [],
          membership: {},
          cluster_colors: %{},
          name_to_id: %{},
          cluster_names: %{},
          cluster_ids: []
        },
        gaps: nil,
        highlighted_dates: [],
        selected_gap: nil,
        selected_cluster: nil,
        selected_day: nil,
        date_range: nil,
        mood_transitions: [],
        smoothed_daily: [],
        stats: nil,
        cluster_names: %{},
        full_date_range: nil
      )

    if connected?(socket), do: send(self(), :load_data)

    {:ok, socket}
  end

  def handle_info(:load_data, socket) do
    tasks = %{
      data: Task.async(fn -> Ish.data() end),
      analysis: Task.async(fn -> Ish.cluster(@default_k, @default_m) end),
      gaps: Task.async(fn -> Ish.gaps() end)
    }

    results = Map.new(tasks, fn {key, task} -> {key, Task.await(task, 15_000)} end)

    case {results.data, results.analysis, results.gaps} do
      {{:ok, entries}, {:ok, raw_analysis}, {:ok, raw_gaps}} ->
        analysis = DataTransforms.parse_analysis(raw_analysis, entries)

        gaps =
          raw_gaps |> GapData.from_api() |> DataTransforms.remap_gap_keys(analysis.name_to_id)

        socket =
          socket
          |> assign(
            loading: false,
            entries: entries,
            analysis: analysis,
            gaps: gaps
          )
          |> push_viz_data()

        {:noreply, socket}

      _ ->
        {:noreply, assign(socket, loading: false, error: "Could not connect to Ish API")}
    end
  end

  def handle_event("day_selected", %{"date" => date}, socket) do
    day_detail = DataTransforms.build_day_detail(date, socket.assigns)

    {:noreply,
     socket
     |> assign(highlighted_dates: [date], selected_gap: nil, selected_day: day_detail)
     |> push_event("highlight-calendar", %{dates: [date]})
     |> push_event("day-focus", %{day: day_detail})}
  end

  def handle_event("lasso_selected", %{"dates" => dates}, socket) do
    {:noreply,
     socket
     |> assign(highlighted_dates: dates)
     |> push_event("highlight-calendar", %{dates: dates})}
  end

  def handle_event("gap_selected", %{"start" => start, "length" => length}, socket) do
    gap = %{"start" => start, "length" => length}
    len = if is_binary(length), do: String.to_integer(length), else: length

    {:noreply,
     socket
     |> assign(selected_gap: gap, highlighted_dates: [])
     |> push_event("highlight-calendar-gap", %{start: start, length: len})}
  end

  def handle_event("clear_highlights", _params, socket) do
    {:noreply,
     socket
     |> assign(highlighted_dates: [], selected_gap: nil, selected_cluster: nil, selected_day: nil)
     |> push_event("highlight-calendar", %{dates: []})
     |> push_event("isolate-cluster", %{cluster: nil})
     |> push_event("day-focus", %{day: nil})}
  end

  def handle_event("cluster_selected", %{"cluster" => cluster}, socket) do
    selected = if socket.assigns.selected_cluster == cluster, do: nil, else: cluster

    socket =
      socket
      |> assign(selected_cluster: selected, highlighted_dates: [], selected_gap: nil)
      |> push_event("isolate-cluster", %{
        cluster: selected,
        clusterColors: socket.assigns.analysis.cluster_colors
      })
      |> push_gap_data_for_cluster(selected)

    {:noreply, socket}
  end

  def handle_event("brush_changed", %{"start" => start, "end" => end_date}, socket)
      when is_binary(start) and start != "" and is_binary(end_date) and end_date != "" do
    range = {start, end_date}

    socket =
      socket
      |> assign(date_range: range, highlighted_dates: [], selected_gap: nil)
      |> push_event("highlight-calendar", %{dates: dates_in_range(socket.assigns.entries, range)})

    {:noreply, socket}
  end

  def handle_event("brush_changed", _params, socket) do
    socket =
      socket
      |> assign(date_range: nil, highlighted_dates: [])
      |> push_event("highlight-calendar", %{dates: []})
      |> push_event("clear-brush", %{})

    {:noreply, socket}
  end

  # --- Push helpers ---

  defp push_viz_data(socket) do
    %{entries: entries, analysis: analysis} = socket.assigns

    smoothed_daily =
      entries
      |> DataTransforms.daily_dominants(analysis)
      |> DataTransforms.smooth_runs()

    dates = Enum.map(entries, & &1["date"])
    sorted_dates = Enum.sort(dates)

    date_range =
      case sorted_dates do
        [] -> nil
        _ -> %{start: List.first(sorted_dates), end: List.last(sorted_dates)}
      end

    socket
    |> assign(smoothed_daily: smoothed_daily, full_date_range: date_range)
    |> push_mood_transitions()
    |> assign_narrative_stats()
    |> push_mood_trajectory()
    |> push_calendar_data()
    |> push_gap_data()
    |> push_brush_data()
    |> push_radar_data()
    |> push_stream_data()
    |> push_mood_flowers()
    |> push_distribution_data()
    |> push_seasonality_data()
    |> push_ambiguity_data()
    |> push_drift_data()
    |> push_event("highlight-calendar", %{dates: []})
    |> push_event("isolate-cluster", %{cluster: nil})
  end

  defp assign_narrative_stats(socket) do
    assign(socket,
      stats: DataTransforms.narrative_stats(socket.assigns),
      cluster_names: socket.assigns.analysis.cluster_names
    )
  end

  defp push_calendar_data(socket) do
    %{entries: entries, analysis: analysis, gaps: gaps, smoothed_daily: daily} = socket.assigns
    days = DataTransforms.build_calendar_days(entries, analysis, gaps)

    transition_dates =
      daily
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.filter(fn [a, b] -> a.cluster != b.cluster end)
      |> Enum.map(fn [_a, b] -> b.date end)

    push_event(socket, "update-calendar", %{
      days: Enum.map(days, &CalendarDay.to_event/1),
      clusterColors: analysis.cluster_colors,
      clusterNames: analysis.cluster_names,
      transitionDates: transition_dates
    })
  end

  defp push_gap_data(socket) do
    %{analysis: analysis, gaps: gaps} = socket.assigns

    case gaps do
      nil ->
        socket

      %GapData{} = g ->
        push_event(socket, "update-gaps", %{
          transitions: g.transitions,
          lengthDistribution: g.length_distribution,
          imputedMemberships: g.imputed_memberships,
          dateRange: socket.assigns.full_date_range,
          clusterColors: analysis.cluster_colors,
          clusterNames: analysis.cluster_names
        })
    end
  end

  defp push_gap_data_for_cluster(socket, nil), do: push_gap_data(socket)

  defp push_gap_data_for_cluster(socket, cluster) do
    %{analysis: analysis, gaps: gaps} = socket.assigns

    case gaps do
      nil ->
        socket

      %GapData{} = g ->
        filtered =
          Enum.filter(g.transitions, fn t ->
            before = t["before"] || %{}
            after_m = t["after"] || %{}
            Map.get(before, cluster, 0) >= 0.3 or Map.get(after_m, cluster, 0) >= 0.3
          end)

        push_event(socket, "update-gaps", %{
          transitions: filtered,
          lengthDistribution: g.length_distribution,
          imputedMemberships: g.imputed_memberships,
          dateRange: socket.assigns.full_date_range,
          clusterColors: analysis.cluster_colors,
          clusterNames: analysis.cluster_names
        })
    end
  end

  defp push_brush_data(socket) do
    dates = Enum.map(socket.assigns.entries, & &1["date"])
    push_event(socket, "update-brush-timeline", %{dates: dates})
  end

  defp push_radar_data(socket) do
    %{analysis: analysis} = socket.assigns
    centroids = DataTransforms.build_centroids(analysis)

    push_event(socket, "update-radar", %{
      centroids: centroids,
      clusterColors: analysis.cluster_colors,
      dimensions: DataTransforms.dimensions()
    })
  end

  defp push_stream_data(socket) do
    %{entries: entries, analysis: analysis} = socket.assigns

    series =
      entries
      |> Enum.with_index()
      |> Enum.map(fn {entry, idx} ->
        mems =
          DataTransforms.build_memberships(elem(analysis.membership, idx), analysis.clusters)

        %{date: entry["date"], memberships: mems}
      end)

    push_event(socket, "update-stream", %{
      series: series,
      clusterColors: analysis.cluster_colors,
      clusterIds: analysis.cluster_ids,
      clusterNames: analysis.cluster_names
    })
  end

  defp push_mood_flowers(socket) do
    %{entries: entries, analysis: analysis, smoothed_daily: daily} = socket.assigns
    flowers = DataTransforms.build_mood_flowers(entries, daily)

    push_event(socket, "update-flowers", %{
      flowers: flowers,
      dimensions: DataTransforms.dimensions(),
      clusterColors: analysis.cluster_colors,
      clusterNames: analysis.cluster_names
    })
  end

  defp push_mood_trajectory(socket) do
    %{entries: entries, analysis: analysis, smoothed_daily: daily} = socket.assigns
    points = DataTransforms.build_trajectory(entries, daily)

    push_event(socket, "update-trajectory", %{
      points: points,
      annotations: Annotations.all(),
      clusterColors: analysis.cluster_colors,
      clusterNames: analysis.cluster_names
    })
  end

  defp push_distribution_data(socket) do
    %{entries: entries, analysis: analysis, smoothed_daily: daily} = socket.assigns
    cluster_by_date = Map.new(daily, fn d -> {d.date, d.cluster} end)

    points =
      Enum.map(entries, fn e ->
        %{
          dimensions: e["dimensions"] || %{},
          cluster: Map.get(cluster_by_date, e["date"])
        }
      end)

    clusters =
      Enum.map(analysis.clusters, fn c ->
        %{
          id: c["id"],
          name: c["name"],
          color: Map.get(analysis.cluster_colors, c["id"], "#666")
        }
      end)

    push_event(socket, "update-distributions", %{
      points: points,
      dimensions: DataTransforms.dimensions(),
      clusters: clusters
    })
  end

  defp push_mood_transitions(socket) do
    %{analysis: analysis, smoothed_daily: daily} = socket.assigns

    # Find transition points (where dominant cluster changes)
    transitions =
      daily
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.filter(fn [a, b] -> a.cluster != b.cluster end)
      |> Enum.map(fn [a, b] -> %{date: b.date, from: a.cluster, to: b.cluster} end)

    # Build segments (runs of the same cluster)
    segments = DataTransforms.build_segments(daily)

    # Sankey data: monthly transition flows
    monthly_flows =
      transitions
      |> Enum.group_by(fn t -> String.slice(t.date, 0, 7) end)
      |> Enum.sort_by(fn {month, _} -> month end)
      |> Enum.map(fn {month, ts} ->
        flows =
          Enum.reduce(ts, %{}, fn t, acc ->
            key = "#{t.from}->#{t.to}"
            Map.update(acc, key, 1, &(&1 + 1))
          end)

        %{month: month, flows: flows}
      end)

    socket
    |> assign(mood_transitions: transitions)
    |> push_event("update-mood-transitions", %{
      transitions: transitions,
      segments: segments,
      monthlyFlows: monthly_flows,
      clusterIds: analysis.cluster_ids,
      clusterNames: analysis.cluster_names,
      clusterColors: analysis.cluster_colors
    })
  end

  defp push_seasonality_data(socket) do
    %{analysis: analysis, smoothed_daily: daily} = socket.assigns
    seasonality = DataTransforms.build_seasonality(daily)

    push_event(socket, "update-seasonality", %{
      months: seasonality,
      clusterColors: analysis.cluster_colors,
      clusterNames: analysis.cluster_names,
      clusterIds: analysis.cluster_ids
    })
  end

  defp push_ambiguity_data(socket) do
    %{entries: entries, analysis: analysis} = socket.assigns
    bins = DataTransforms.build_ambiguity_histogram(entries, analysis)

    push_event(socket, "update-ambiguity", %{
      bins: bins,
      threshold: 0.45
    })
  end

  defp push_drift_data(socket) do
    %{entries: entries} = socket.assigns
    drift = DataTransforms.build_drift(entries)

    push_event(socket, "update-drift", %{
      dimensions: drift
    })
  end

  # --- Helpers ---

  defp dates_in_range(entries, {start, end_date}) do
    entries
    |> Enum.map(& &1["date"])
    |> Enum.filter(fn d -> d >= start and d <= end_date end)
  end

  # --- Render ---

  def render(assigns) do
    ~H"""
    <div id="mood-experience" phx-hook="MoodExperience" class="mood-explorer p-4 max-w-6xl mx-auto">
      <%= if @error do %>
        <div class="bg-red-900/50 border border-red-500 text-red-200 px-4 py-3 rounded mb-4">
          {@error}
        </div>
      <% end %>

      <%= if @loading do %>
        <div class="flex items-center justify-center h-64">
          <p class="text-gray-400 text-lg">Loading mood data...</p>
        </div>
      <% end %>

      <%= if @stats do %>
        <Sections.hero stats={@stats} />
        <Sections.sticky_legend analysis={@analysis} selected_cluster={@selected_cluster} />
        <Sections.intro stats={@stats} />

        <div id="mood-tour" phx-hook="MoodTour" phx-update="ignore"></div>

        <Sections.chapter_states
          stats={@stats}
          analysis={@analysis}
          selected_cluster={@selected_cluster}
        />
        <Sections.chapter_day_by_day
          stats={@stats}
          analysis={@analysis}
          date_range={@date_range}
          highlighted_dates={@highlighted_dates}
          selected_gap={@selected_gap}
        />
        <Sections.chapter_shifts
          stats={@stats}
          analysis={@analysis}
          mood_transitions={@mood_transitions}
          selected_cluster={@selected_cluster}
          highlighted_dates={@highlighted_dates}
          cluster_names={@cluster_names}
        />
        <Sections.chapter_under_hood stats={@stats} />
        <Sections.chapter_gaps
          stats={@stats}
          gaps={@gaps}
          analysis={@analysis}
          selected_cluster={@selected_cluster}
          cluster_names={@cluster_names}
        />
        <Sections.afterword />
      <% end %>
    </div>
    """
  end
end
