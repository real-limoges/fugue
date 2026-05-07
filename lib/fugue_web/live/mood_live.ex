defmodule FugueWeb.MoodLive do
  @moduledoc "Mood journal explorer -- fuzzy-clustering visualization of daily mood entries."

  use FugueWeb, :live_view

  alias FugueWeb.MoodLive.{Annotations, DataTransforms, ExperiencePanel, Sections}
  alias FugueWeb.MoodLive.Structs.{AnalysisResult, GapData}
  alias Fugue.Ish

  @default_k 3
  @default_m 1.5

  # Pinned so clusters stay stable as new entries land. Bump when promoting an epilogue.
  @from ~D[2022-04-01]
  @to ~D[2026-03-30]

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
        full_date_range: nil,
        calendar_days: [],
        transition_dates: [],
        stream_series: [],
        radar_centroids: [],
        radar_dimensions: [],
        ambiguity_bins: [],
        ambiguity_threshold: 0.45,
        timeline_segments: [],
        season_months: [],
        drift_dimensions: [],
        mood_flowers_list: [],
        flower_dimensions: [],
        distribution_points: [],
        distribution_clusters: [],
        gap_transitions: [],
        imputed_memberships: %{},
        trajectory_points: [],
        trajectory_annotations: []
      )

    if connected?(socket), do: send(self(), :load_data)

    {:ok, socket}
  end

  def handle_info(:load_data, socket) do
    tasks = %{
      data: Task.async(fn -> Ish.data(@from, @to) end),
      analysis: Task.async(fn -> Ish.cluster(@default_k, @default_m, @from, @to) end),
      gaps: Task.async(fn -> Ish.gaps(@from, @to) end)
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
     assign(socket, highlighted_dates: [date], selected_gap: nil, selected_day: day_detail)}
  end

  def handle_event("lasso_selected", %{"dates" => dates}, socket) do
    {:noreply, assign(socket, highlighted_dates: dates)}
  end

  def handle_event("gap_selected", %{"start" => start, "length" => length}, socket) do
    gap = %{"start" => start, "length" => length}
    {:noreply, assign(socket, selected_gap: gap, highlighted_dates: [])}
  end

  def handle_event("clear_highlights", _params, socket) do
    {:noreply,
     assign(socket,
       highlighted_dates: [],
       selected_gap: nil,
       selected_cluster: nil,
       selected_day: nil
     )}
  end

  def handle_event("cluster_selected", %{"cluster" => cluster}, socket) do
    selected = if socket.assigns.selected_cluster == cluster, do: nil, else: cluster

    socket =
      socket
      |> assign(selected_cluster: selected, highlighted_dates: [], selected_gap: nil)
      |> push_gap_data_for_cluster(selected)

    {:noreply, socket}
  end

  def handle_event("brush_changed", %{"start" => start, "end" => end_date}, socket)
      when is_binary(start) and start != "" and is_binary(end_date) and end_date != "" do
    range = {start, end_date}
    dates = dates_in_range(socket.assigns.entries, range)
    {:noreply, assign(socket, date_range: range, highlighted_dates: dates, selected_gap: nil)}
  end

  def handle_event("brush_changed", _params, socket) do
    {:noreply,
     socket
     |> assign(date_range: nil, highlighted_dates: [])
     |> push_event("clear-brush", %{})}
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

    assign(socket, calendar_days: days, transition_dates: transition_dates)
  end

  defp push_gap_data(socket) do
    case socket.assigns.gaps do
      nil ->
        socket

      %GapData{} = g ->
        assign(socket, gap_transitions: g.transitions, imputed_memberships: g.imputed_memberships)
    end
  end

  defp push_gap_data_for_cluster(socket, nil), do: push_gap_data(socket)

  defp push_gap_data_for_cluster(socket, cluster) do
    case socket.assigns.gaps do
      nil ->
        socket

      %GapData{} = g ->
        filtered =
          Enum.filter(g.transitions, fn t ->
            before = t["before"] || %{}
            after_m = t["after"] || %{}
            Map.get(before, cluster, 0) >= 0.3 or Map.get(after_m, cluster, 0) >= 0.3
          end)

        assign(socket, gap_transitions: filtered, imputed_memberships: g.imputed_memberships)
    end
  end

  defp push_brush_data(socket) do
    dates = Enum.map(socket.assigns.entries, & &1["date"])
    push_event(socket, "update-brush-timeline", %{dates: dates})
  end

  defp push_radar_data(socket) do
    centroids = DataTransforms.build_centroids(socket.assigns.analysis)
    assign(socket, radar_centroids: centroids, radar_dimensions: DataTransforms.dimensions())
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

    assign(socket, stream_series: series)
  end

  defp push_mood_flowers(socket) do
    %{entries: entries, smoothed_daily: daily} = socket.assigns
    flowers = DataTransforms.build_mood_flowers(entries, daily)
    assign(socket, mood_flowers_list: flowers, flower_dimensions: DataTransforms.dimensions())
  end

  defp push_mood_trajectory(socket) do
    %{entries: entries, smoothed_daily: daily} = socket.assigns
    points = DataTransforms.build_trajectory(entries, daily)

    assign(socket,
      trajectory_points: points,
      trajectory_annotations: Annotations.all()
    )
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

    assign(socket, distribution_points: points, distribution_clusters: clusters)
  end

  defp push_mood_transitions(socket) do
    daily = socket.assigns.smoothed_daily

    transitions =
      daily
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.filter(fn [a, b] -> a.cluster != b.cluster end)
      |> Enum.map(fn [a, b] -> %{date: b.date, from: a.cluster, to: b.cluster} end)

    segments = DataTransforms.build_segments(daily)

    assign(socket, mood_transitions: transitions, timeline_segments: segments)
  end

  defp push_seasonality_data(socket) do
    assign(socket, season_months: DataTransforms.build_seasonality(socket.assigns.smoothed_daily))
  end

  defp push_ambiguity_data(socket) do
    %{entries: entries, analysis: analysis} = socket.assigns
    bins = DataTransforms.build_ambiguity_histogram(entries, analysis)
    assign(socket, ambiguity_bins: bins, ambiguity_threshold: 0.45)
  end

  defp push_drift_data(socket) do
    assign(socket, drift_dimensions: DataTransforms.build_drift(socket.assigns.entries))
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
    <div id="mood-experience" class="mood-explorer p-4 mx-auto">
      <ExperiencePanel.ambient
        selected_day={@selected_day}
        selected_cluster={@selected_cluster}
        cluster_colors={@analysis.cluster_colors}
      />
      <ExperiencePanel.panel selected_day={@selected_day} />
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
        <Sections.hero
          stats={@stats}
          trajectory_points={@trajectory_points}
          trajectory_annotations={@trajectory_annotations}
          analysis={@analysis}
          selected_day={@selected_day}
        />
        <Sections.sticky_legend analysis={@analysis} selected_cluster={@selected_cluster} />

        <div class="max-w-3xl mx-auto">
          <Sections.intro stats={@stats} />

          <div id="mood-tour" phx-hook="MoodTour" phx-update="ignore"></div>

          <Sections.chapter_states
            stats={@stats}
            analysis={@analysis}
            selected_cluster={@selected_cluster}
            radar_centroids={@radar_centroids}
            radar_dimensions={@radar_dimensions}
            ambiguity_bins={@ambiguity_bins}
            ambiguity_threshold={@ambiguity_threshold}
          />
          <Sections.interstitial_after_states />
          <Sections.chapter_day_by_day
            stats={@stats}
            analysis={@analysis}
            date_range={@date_range}
            highlighted_dates={@highlighted_dates}
            selected_gap={@selected_gap}
            selected_cluster={@selected_cluster}
            selected_day={@selected_day}
            calendar_days={@calendar_days}
            transition_dates={@transition_dates}
            stream_series={@stream_series}
            season_months={@season_months}
          />
          <Sections.chapter_shifts
            stats={@stats}
            analysis={@analysis}
            mood_transitions={@mood_transitions}
            selected_cluster={@selected_cluster}
            highlighted_dates={@highlighted_dates}
            cluster_names={@cluster_names}
            timeline_segments={@timeline_segments}
          />
          <Sections.chapter_under_hood
            stats={@stats}
            drift_dimensions={@drift_dimensions}
            analysis={@analysis}
            mood_flowers_list={@mood_flowers_list}
            flower_dimensions={@flower_dimensions}
            selected_day={@selected_day}
            distribution_points={@distribution_points}
            distribution_clusters={@distribution_clusters}
          />
          <Sections.interstitial_before_gaps />
          <Sections.chapter_gaps
            stats={@stats}
            analysis={@analysis}
            cluster_names={@cluster_names}
            gap_transitions={@gap_transitions}
            imputed_memberships={@imputed_memberships}
            full_date_range={@full_date_range}
          />
          <Sections.afterword />
        </div>
      <% end %>
    </div>
    """
  end
end
