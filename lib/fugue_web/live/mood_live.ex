defmodule FugueWeb.MoodLive do
  @moduledoc "Mood journal explorer: fuzzy-clustering visualization of daily mood entries."

  use FugueWeb, :live_view

  alias FugueWeb.MoodLive.{DataTransforms, ExperiencePanel, Focus, Sections, Snapshot}
  alias FugueWeb.MoodLive.Structs.{AnalysisResult, GapData}
  alias Fugue.Mood.Wire

  @default_k 3
  @default_m 1.5

  # Pinned so clusters stay stable as new entries land. Bump when promoting an epilogue.
  @from ~D[2022-04-01]
  @to ~D[2026-03-30]

  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        loading: true,
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
        focus: :none,
        date_range: nil,
        snapshot: nil
      )

    if connected?(socket), do: send(self(), :load_data)

    {:ok, socket}
  end

  def handle_info(:load_data, socket) do
    # Fugue.Mood.Wire computes from the bundled dataset in-process (no I/O,
    # can't fail the way an Ish HTTP call could) -- still parallelized via
    # Task since clustering + gap analysis are genuine CPU work over ~1000
    # points, run twice independently (see Fugue.Mood.Wire's moduledoc).
    tasks = %{
      data: Task.async(fn -> Wire.data(@from, @to) end),
      analysis: Task.async(fn -> Wire.cluster(@default_k, @default_m, @from, @to) end),
      gaps: Task.async(fn -> Wire.gaps(@from, @to) end)
    }

    results = Map.new(tasks, fn {key, task} -> {key, Task.await(task, 15_000)} end)

    {:ok, entries} = results.data
    {:ok, raw_analysis} = results.analysis
    {:ok, raw_gaps} = results.gaps

    analysis = DataTransforms.parse_analysis(raw_analysis, entries)
    gaps = raw_gaps |> GapData.from_api() |> DataTransforms.remap_gap_keys(analysis.name_to_id)
    snapshot = Snapshot.from(entries, analysis, gaps)

    socket =
      socket
      |> assign(
        loading: false,
        entries: entries,
        analysis: analysis,
        gaps: gaps,
        snapshot: snapshot
      )
      |> push_event("update-brush-timeline", %{dates: Enum.map(entries, & &1["date"])})

    {:noreply, socket}
  end

  def handle_event("day_selected", %{"date" => date}, socket) do
    {:noreply, assign(socket, :focus, Focus.select_day(socket.assigns.focus, date))}
  end

  def handle_event("gap_selected", %{"start" => start, "length" => length}, socket) do
    gap = %{"start" => start, "length" => length}
    {:noreply, assign(socket, :focus, Focus.select_gap(socket.assigns.focus, gap))}
  end

  def handle_event("clear_highlights", _params, socket) do
    {:noreply, assign(socket, :focus, Focus.clear(socket.assigns.focus))}
  end

  def handle_event("cluster_selected", %{"cluster" => cluster}, socket) do
    {:noreply, assign(socket, :focus, Focus.select_cluster(socket.assigns.focus, cluster))}
  end

  def handle_event("brush_changed", %{"start" => start, "end" => end_date}, socket)
      when is_binary(start) and start != "" and is_binary(end_date) and end_date != "" do
    {:noreply, assign(socket, :date_range, {start, end_date})}
  end

  def handle_event("brush_changed", _params, socket) do
    {:noreply,
     socket
     |> assign(:date_range, nil)
     |> push_event("clear-brush", %{})}
  end

  # --- Render ---

  def render(assigns) do
    assigns = assign_focus_views(assigns)

    ~H"""
    <div id="mood-experience" class="mood-explorer p-4 mx-auto">
      <ExperiencePanel.ambient
        selected_day={@selected_day}
        selected_cluster={@selected_cluster}
        cluster_colors={@analysis.cluster_colors}
      />
      <ExperiencePanel.panel selected_day={@selected_day} />

      <%= if @loading do %>
        <div class="flex items-center justify-center h-64">
          <p class="text-gray-400 text-lg">Loading mood data...</p>
        </div>
      <% end %>

      <%= if @snapshot do %>
        <Sections.hero
          stats={@snapshot.stats}
          trajectory_points={@snapshot.trajectory_points}
          trajectory_annotations={@snapshot.trajectory_annotations}
          analysis={@analysis}
          selected_day={@selected_day}
        />
        <Sections.sticky_legend analysis={@analysis} selected_cluster={@selected_cluster} />

        <div class="max-w-3xl mx-auto">
          <Sections.intro stats={@snapshot.stats} />

          <div id="mood-tour" phx-hook="MoodTour" phx-update="ignore"></div>

          <Sections.chapter_states
            stats={@snapshot.stats}
            analysis={@analysis}
            selected_cluster={@selected_cluster}
            radar_centroids={@snapshot.radar_centroids}
            radar_dimensions={@snapshot.radar_dimensions}
            ambiguity_bins={@snapshot.ambiguity_bins}
            ambiguity_threshold={@snapshot.ambiguity_threshold}
          />
          <Sections.interstitial_after_states />
          <Sections.chapter_day_by_day
            stats={@snapshot.stats}
            analysis={@analysis}
            date_range={@date_range}
            highlighted_dates={@highlighted_dates}
            selected_gap={@selected_gap}
            selected_cluster={@selected_cluster}
            selected_day={@selected_day}
            calendar_days={@snapshot.calendar_days}
            transition_dates={@snapshot.transition_dates}
            stream_series={@snapshot.stream_series}
            season_months={@snapshot.season_months}
          />
          <Sections.chapter_shifts
            stats={@snapshot.stats}
            analysis={@analysis}
            mood_transitions={@snapshot.mood_transitions}
            selected_cluster={@selected_cluster}
            highlighted_dates={@highlighted_dates}
            cluster_names={@snapshot.cluster_names}
            timeline_segments={@snapshot.timeline_segments}
          />
          <Sections.chapter_under_hood
            stats={@snapshot.stats}
            drift_dimensions={@snapshot.drift_dimensions}
            analysis={@analysis}
            mood_flowers_list={@snapshot.mood_flowers_list}
            flower_dimensions={@snapshot.flower_dimensions}
            selected_day={@selected_day}
            distribution_points={@snapshot.distribution_points}
            distribution_clusters={@snapshot.distribution_clusters}
          />
          <Sections.interstitial_before_gaps />
          <Sections.chapter_gaps
            stats={@snapshot.stats}
            analysis={@analysis}
            cluster_names={@snapshot.cluster_names}
            gap_transitions={@gap_transitions}
            imputed_memberships={@imputed_memberships}
            full_date_range={@snapshot.full_date_range}
          />
          <Sections.afterword />
        </div>
      <% end %>

      <.source_link repos={[{"fugue", "lib/fugue/mood"}]} />
    </div>
    """
  end

  # Derive view-shape assigns from focus + brush + loaded data. Centralized
  # so render-time consumers see one focus, not five parallel selection
  # fields. Pure projection; mutating focus is enough to rebuild these.
  defp assign_focus_views(assigns) do
    focus = assigns.focus
    gaps = assigns.gaps

    assigns
    |> assign(:selected_day, day_detail(focus, assigns))
    |> assign(:selected_cluster, focused_cluster(focus))
    |> assign(:selected_gap, focused_gap(focus))
    |> assign(:highlighted_dates, Focus.highlights(focus, assigns.date_range, assigns.entries))
    |> assign(:gap_transitions, Focus.gap_transitions(gaps, focus))
    |> assign(:imputed_memberships, imputed_memberships(gaps))
  end

  defp day_detail({:day, date}, assigns), do: DataTransforms.build_day_detail(date, assigns)
  defp day_detail(_, _), do: nil

  defp focused_cluster({:cluster, cluster}), do: cluster
  defp focused_cluster(_), do: nil

  defp focused_gap({:gap, gap}), do: gap
  defp focused_gap(_), do: nil

  defp imputed_memberships(%GapData{imputed_memberships: m}), do: m
  defp imputed_memberships(_), do: %{}
end
