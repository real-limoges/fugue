defmodule FugueWeb.MoodLive do
  @moduledoc "Mood journal explorer: fuzzy-clustering visualization of daily mood entries."

  use FugueWeb, :live_view

  alias FugueWeb.MoodLive.{Dataset, DataTransforms, ExperiencePanel, Focus, Sections}

  # `dataset` is `:loading` until the connected mount has loaded it, then a
  # `%Dataset{}`, which every section reads from.
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        dataset: :loading,
        focus: :none,
        brush: :all,
        intro: intro_from_connect_params(socket)
      )

    if connected?(socket), do: send(self(), :load_data)

    {:ok, socket}
  end

  # The browser keeps the reader's skip choice in localStorage and sends it
  # as a connect param (app.js). The intro only renders once connected, so
  # the disconnected render never needs it.
  defp intro_from_connect_params(socket) do
    case get_connect_params(socket) do
      %{"mood_skip_intro" => "1"} -> :skipped
      _not_skipped -> :shown
    end
  end

  def handle_info(:load_data, socket) do
    # Computed once per node and shared by every socket; see Dataset.
    {:noreply, assign(socket, :dataset, Dataset.load())}
  end

  def handle_event("day_selected", %{"date" => date}, socket) do
    {:noreply, assign(socket, :focus, Focus.select_day(socket.assigns.focus, date))}
  end

  def handle_event("gap_selected", %{"start" => start, "length" => length}, socket) do
    gap = %{"start" => start, "length" => length}
    {:noreply, assign(socket, :focus, Focus.select_gap(socket.assigns.focus, gap))}
  end

  # The browser has already swapped the elements (Sections.skip_intro_js/0);
  # these keep the server's render in step so the next patch agrees.
  def handle_event("skip_intro", _params, socket) do
    {:noreply, assign(socket, :intro, :skipped)}
  end

  def handle_event("show_intro", _params, socket) do
    {:noreply, assign(socket, :intro, :shown)}
  end

  def handle_event("clear_highlights", _params, socket) do
    {:noreply, assign(socket, :focus, Focus.clear(socket.assigns.focus))}
  end

  def handle_event("cluster_selected", %{"cluster" => cluster}, socket) do
    {:noreply, assign(socket, :focus, Focus.select_cluster(socket.assigns.focus, cluster))}
  end

  # The TemporalBrush hook owns the d3 brush and reports what it ends on: a
  # window, or nothing. The "clear" link clears the brush in the browser
  # (Sections), which arrives here as brush_cleared like any other clear.
  def handle_event("brush_changed", %{"start" => start, "end" => end_date}, socket)
      when is_binary(start) and start != "" and is_binary(end_date) and end_date != "" do
    {:noreply, assign(socket, :brush, {start, end_date})}
  end

  def handle_event("brush_cleared", _params, socket) do
    {:noreply, assign(socket, :brush, :all)}
  end

  # --- Render ---

  def render(%{dataset: :loading} = assigns) do
    ~H"""
    <div id="mood-experience" class="mood-explorer p-4 mx-auto">
      <div class="flex items-center justify-center h-64">
        <p class="text-base-content/60 text-lg">Loading mood data...</p>
      </div>

      <.source_link repos={[{"fugue", "lib/fugue/mood"}]} />
    </div>
    """
  end

  def render(%{dataset: %Dataset{}} = assigns) do
    assigns = assign_focus_views(assigns)

    ~H"""
    <div id="mood-experience" class="mood-explorer p-4 mx-auto">
      <ExperiencePanel.ambient
        selected_day={@selected_day}
        selected_cluster={@selected_cluster}
        cluster_colors={@dataset.analysis.cluster_colors}
      />
      <ExperiencePanel.panel selected_day={@selected_day} />

      <Sections.hero
        stats={@dataset.snapshot.stats}
        trajectory_points={@dataset.snapshot.trajectory_points}
        trajectory_annotations={@dataset.snapshot.trajectory_annotations}
        analysis={@dataset.analysis}
        selected_day={@selected_day}
      />
      <Sections.sticky_legend analysis={@dataset.analysis} selected_cluster={@selected_cluster} />

      <div class="max-w-3xl mx-auto">
        <Sections.intro stats={@dataset.snapshot.stats} intro={@intro} />

        <div id="mood-tour" phx-hook="MoodTour" phx-update="ignore"></div>

        <Sections.chapter_states
          stats={@dataset.snapshot.stats}
          intro={@intro}
          analysis={@dataset.analysis}
          selected_cluster={@selected_cluster}
          radar_centroids={@dataset.snapshot.radar_centroids}
          radar_dimensions={@dataset.snapshot.radar_dimensions}
          ambiguity_bins={@dataset.snapshot.ambiguity_bins}
          ambiguity_threshold={@dataset.snapshot.ambiguity_threshold}
        />
        <Sections.interstitial_after_states />
        <Sections.chapter_day_by_day
          stats={@dataset.snapshot.stats}
          analysis={@dataset.analysis}
          brush={@brush}
          dates={@dataset.dates}
          highlighted_dates={@highlighted_dates}
          selected_gap={@selected_gap}
          selected_cluster={@selected_cluster}
          selected_day={@selected_day}
          calendar_days={@dataset.snapshot.calendar_days}
          transition_dates={@dataset.snapshot.transition_dates}
          stream_series={@dataset.snapshot.stream_series}
          season_months={@dataset.snapshot.season_months}
        />
        <Sections.chapter_shifts
          stats={@dataset.snapshot.stats}
          analysis={@dataset.analysis}
          mood_transitions={@dataset.snapshot.mood_transitions}
          selected_cluster={@selected_cluster}
          highlighted_dates={@highlighted_dates}
          cluster_names={@dataset.snapshot.cluster_names}
          timeline_segments={@dataset.snapshot.timeline_segments}
        />
        <Sections.chapter_under_hood
          stats={@dataset.snapshot.stats}
          drift_dimensions={@dataset.snapshot.drift_dimensions}
          analysis={@dataset.analysis}
          mood_flowers_list={@dataset.snapshot.mood_flowers_list}
          flower_dimensions={@dataset.snapshot.flower_dimensions}
          selected_day={@selected_day}
          distribution_points={@dataset.snapshot.distribution_points}
          distribution_clusters={@dataset.snapshot.distribution_clusters}
        />
        <Sections.interstitial_before_gaps />
        <Sections.chapter_gaps
          stats={@dataset.snapshot.stats}
          analysis={@dataset.analysis}
          cluster_names={@dataset.snapshot.cluster_names}
          gap_transitions={@gap_transitions}
          imputed_memberships={@dataset.gaps.imputed_memberships}
          full_date_range={@dataset.snapshot.full_date_range}
        />
        <Sections.afterword />
      </div>

      <.source_link repos={[{"fugue", "lib/fugue/mood"}]} />
    </div>
    """
  end

  # Derive view-shape assigns from focus + brush + loaded data. Centralized
  # so render-time consumers see one focus, not five parallel selection
  # fields. Pure projection; mutating focus is enough to rebuild these.
  defp assign_focus_views(%{dataset: dataset, focus: focus} = assigns) do
    assigns
    |> assign(:selected_day, day_detail(focus, dataset))
    |> assign(:selected_cluster, focused_cluster(focus))
    |> assign(:selected_gap, focused_gap(focus))
    |> assign(:highlighted_dates, Focus.highlights(focus, assigns.brush, dataset.entries))
    |> assign(:gap_transitions, Focus.gap_transitions(dataset.gaps, focus))
  end

  defp day_detail({:day, date}, dataset), do: DataTransforms.build_day_detail(date, dataset)
  defp day_detail(_, _), do: nil

  defp focused_cluster({:cluster, cluster}), do: cluster
  defp focused_cluster(_), do: nil

  defp focused_gap({:gap, gap}), do: gap
  defp focused_gap(_), do: nil
end
