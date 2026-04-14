defmodule FugueWeb.MoodLive do
  @moduledoc "Mood journal explorer — fuzzy-clustering visualization of daily mood entries."

  use FugueWeb, :live_view

  alias FugueWeb.MoodLive.{
    Calendar,
    ClusterTransitions,
    DataTransforms,
    GapAnalysis,
    MoodTransitions,
    ParamControls
  }

  alias FugueWeb.MoodLive.Structs.{AnalysisResult, CalendarDay, GapData}
  alias Fugue.Ish

  @default_k 3
  @default_m 1.5

  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        k: @default_k,
        m: @default_m,
        loading: true,
        error: nil,
        entries: [],
        analysis: %AnalysisResult{
          clusters: [],
          membership: [],
          cluster_colors: %{},
          name_to_id: %{}
        },
        gaps: nil,
        highlighted_dates: [],
        selected_gap: nil,
        selected_cluster: nil,
        selected_day: nil,
        date_range: nil,
        mood_transitions: [],
        smoothed_daily: []
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

  def handle_info({:recluster, k, m}, socket) do
    case Ish.cluster(k, m) do
      {:ok, raw} ->
        analysis = DataTransforms.parse_analysis(raw, socket.assigns.entries)

        socket =
          socket
          |> assign(
            analysis: analysis,
            highlighted_dates: [],
            selected_gap: nil,
            selected_cluster: nil,
            date_range: nil
          )
          |> push_viz_data()

        {:noreply, socket}

      {:error, _} ->
        {:noreply, assign(socket, error: "Clustering failed")}
    end
  end

  def handle_event("update_params", %{"k" => k_str, "m" => m_str}, socket) do
    k = String.to_integer(k_str)

    m =
      case Float.parse(m_str) do
        {val, _} -> val
        :error -> socket.assigns.m
      end

    socket = assign(socket, k: k, m: m)
    send(self(), {:recluster, k, m})
    {:noreply, socket}
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

    socket
    |> assign(smoothed_daily: smoothed_daily)
    |> push_mood_trajectory()
    |> push_calendar_data()
    |> push_gap_data()
    |> push_brush_data()
    |> push_radar_data()
    |> push_stream_data()
    |> push_mood_flowers()
    |> push_correlation_data()
    |> push_distribution_data()
    |> push_mood_transitions()
    |> push_event("highlight-calendar", %{dates: []})
    |> push_event("isolate-cluster", %{cluster: nil})
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
      clusterNames: Enum.into(analysis.clusters, %{}, fn c -> {c["id"], c["name"]} end),
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
          clusterColors: analysis.cluster_colors
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
          clusterColors: analysis.cluster_colors
        })
    end
  end

  defp push_brush_data(socket) do
    dates = Enum.map(socket.assigns.entries, & &1["date"])
    push_event(socket, "update-brush-timeline", %{dates: dates})
  end

  defp push_radar_data(socket) do
    %{entries: entries, analysis: analysis} = socket.assigns
    centroids = DataTransforms.build_centroids(entries, analysis)

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
          DataTransforms.build_memberships(Enum.at(analysis.membership, idx), analysis.clusters)

        %{date: entry["date"], memberships: mems}
      end)

    cluster_ids = Enum.map(analysis.clusters, & &1["id"])

    cluster_names =
      Enum.into(analysis.clusters, %{}, fn c -> {c["id"], c["name"]} end)

    push_event(socket, "update-stream", %{
      series: series,
      clusterColors: analysis.cluster_colors,
      clusterIds: cluster_ids,
      clusterNames: cluster_names
    })
  end

  defp push_mood_flowers(socket) do
    %{entries: entries, analysis: analysis, smoothed_daily: daily} = socket.assigns
    flowers = DataTransforms.build_mood_flowers(entries, daily)

    push_event(socket, "update-flowers", %{
      flowers: flowers,
      dimensions: DataTransforms.dimensions(),
      clusterColors: analysis.cluster_colors,
      clusterNames: Enum.into(analysis.clusters, %{}, fn c -> {c["id"], c["name"]} end)
    })
  end

  defp push_mood_trajectory(socket) do
    %{entries: entries, analysis: analysis, smoothed_daily: daily} = socket.assigns
    points = DataTransforms.build_trajectory(entries, daily)

    push_event(socket, "update-trajectory", %{
      points: points,
      clusterColors: analysis.cluster_colors,
      clusterNames: Enum.into(analysis.clusters, %{}, fn c -> {c["id"], c["name"]} end)
    })
  end

  defp push_correlation_data(socket) do
    entries = socket.assigns.entries
    matrix = DataTransforms.build_correlation_matrix(entries, DataTransforms.dimensions())

    push_event(socket, "update-correlations", %{
      matrix: matrix,
      dimensions: DataTransforms.dimensions()
    })
  end

  defp push_distribution_data(socket) do
    entries = socket.assigns.entries

    push_event(socket, "update-distributions", %{
      entries: Enum.map(entries, fn e -> %{dimensions: e["dimensions"]} end),
      dimensions: DataTransforms.dimensions()
    })
  end

  defp push_mood_transitions(socket) do
    %{analysis: analysis, smoothed_daily: daily} = socket.assigns
    clusters = analysis.clusters
    cluster_ids = Enum.map(clusters, & &1["id"])
    id_names = Enum.into(clusters, %{}, fn c -> {c["id"], c["name"]} end)

    # Find transition points (where dominant cluster changes)
    transitions =
      daily
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.filter(fn [a, b] -> a.cluster != b.cluster end)
      |> Enum.map(fn [a, b] -> %{date: b.date, from: a.cluster, to: b.cluster} end)

    # Build segments (runs of the same cluster)
    segments = DataTransforms.build_segments(daily)

    # Chord data: transition counts between all pairs
    chord_matrix =
      Enum.reduce(transitions, %{}, fn t, acc ->
        Map.update(acc, {t.from, t.to}, 1, &(&1 + 1))
      end)

    chord_rows =
      Enum.map(cluster_ids, fn from ->
        Enum.map(cluster_ids, fn to ->
          Map.get(chord_matrix, {from, to}, 0)
        end)
      end)

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
      chordMatrix: chord_rows,
      monthlyFlows: monthly_flows,
      clusterIds: cluster_ids,
      clusterNames: id_names,
      clusterColors: analysis.cluster_colors
    })
  end

  # --- Helpers ---

  defp id_to_name(clusters) do
    Enum.into(clusters, %{}, fn c -> {c["id"], c["name"]} end)
  end

  defp dates_in_range(entries, {start, end_date}) do
    entries
    |> Enum.map(& &1["date"])
    |> Enum.filter(fn d -> d >= start and d <= end_date end)
  end

  # --- Render ---

  def render(assigns) do
    assigns =
      if not assigns.loading do
        Phoenix.Component.assign(assigns, :stats, DataTransforms.narrative_stats(assigns))
      else
        assigns
      end

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
      <% else %>
        <%!-- ═══════════════════════════════════════ --%>
        <%!-- HERO: FOUR YEARS AS ONE LINE             --%>
        <%!-- ═══════════════════════════════════════ --%>

        <section class="mb-20 -mx-4 md:-mx-8">
          <div class="bg-black/40 border-y border-white/5 py-10 px-4 md:px-8">
            <div class="max-w-5xl mx-auto">
              <div
                id="mood-trajectory"
                phx-hook="MoodTrajectory"
                phx-update="ignore"
                class="w-full"
                style="min-height: 520px;"
              >
              </div>

              <div class="mt-8 max-w-xl ml-auto border-t border-white/10 pt-5 text-[11px] leading-relaxed text-gray-400 font-serif">
                <div class="uppercase tracking-[0.2em] text-[10px] text-gray-500 mb-1">
                  Wall text
                </div>
                <div class="text-gray-200 text-sm mb-1 italic">
                  Four Years, One Line
                </div>
                <div class="text-gray-500 mb-3">
                  {@stats.date_range && elem(@stats.date_range, 0)} – {@stats.date_range &&
                    elem(@stats.date_range, 1)} &middot; PCA projection on daily self-ratings &middot; real limoges
                </div>
                <p class="mb-2">
                  Every evening before bed for the past four years I wrote down five numbers about how I was doing. This is all of them, squashed onto a flat plane by a little math that tries to preserve the shape of the whole thing while throwing the rest away.
                </p>
                <p>
                  One dot per day. The line is the order I lived them in. The colors are the mood states the clustering found later, painted back onto the path after the fact. I didn't pick where any of it went.
                </p>
              </div>
            </div>
          </div>
        </section>

        <div id="mood-intro" phx-hook="MoodIntroGate">
          <%!-- ═══════════════════════════════════════ --%>
          <%!-- PREAMBLE                                 --%>
          <%!-- ═══════════════════════════════════════ --%>

          <header class="mb-16 max-w-2xl">
            <h1 class="text-3xl font-bold tracking-tight">My Mood Journal</h1>
            <p class="text-gray-500 mt-2 mb-10">
              {@stats.entry_count} days tracked
              <%= if @stats.date_range do %>
                from {elem(@stats.date_range, 0)} to {elem(@stats.date_range, 1)}
              <% end %>
            </p>

            <p class="text-sm text-gray-300 mb-5 leading-relaxed">
              I have bipolar disorder. The cartoon version is two poles — manic, depressed — but the inside of it is finer-grained than that. Most days aren't either. Most days are <em>something</em>, and that something is hard to name with two words.
            </p>
            <p class="text-sm text-gray-300 mb-5 leading-relaxed">
              So I tracked mine. Every day, a handful of numbers about how I was doing. After a few hundred days I had enough to ask the data what
              <em>it</em>
              thought my states were, instead of what a diagnostic manual said they should be. I ran it through an algorithm that lets a day belong
              <em>partly</em>
              to more than one state instead of forcing it into one.
            </p>
            <p class="text-sm text-gray-300 leading-relaxed">
              If "fuzzy clustering" doesn't click yet, that's okay — drag the dot below and watch what happens.
            </p>
          </header>

          <%!-- ═══════════════════════════════════════ --%>
          <%!-- SANDBOX: TRY IT                          --%>
          <%!-- ═══════════════════════════════════════ --%>

          <section class="mb-20">
            <h2 class="text-sm font-semibold uppercase tracking-widest text-gray-200 mb-4">
              Try it first
            </h2>
            <p class="text-sm text-gray-400 mb-6 max-w-2xl leading-relaxed">
              Three fake clusters on an axis with no units. Drag the dot. Drag the sliders. The bar shows how much the dot belongs to each cluster — at high fuzziness it belongs to
              <em>all</em>
              of them, a little.
            </p>

            <div
              id="mood-tour-sandbox"
              phx-hook="MoodTourSandbox"
              phx-update="ignore"
              class="bg-base-200 rounded-lg p-6"
            >
            </div>

            <div class="flex justify-between items-center mt-8">
              <button
                type="button"
                data-skip-intro
                class="text-xs uppercase tracking-widest text-gray-600 cursor-pointer hover:text-gray-400 transition-colors"
              >
                Skip intro
              </button>
              <button
                type="button"
                data-start-tour
                class="text-xs uppercase tracking-widest text-gray-300 cursor-pointer hover:text-white transition-colors"
              >
                Show me around &rsaquo;
              </button>
            </div>
          </section>
        </div>

        <div id="mood-tour" phx-hook="MoodTour" phx-update="ignore"></div>

        <%!-- ═══════════════════════════════════════ --%>
        <%!-- CHAPTER 1: WHO AM I                      --%>
        <%!-- ═══════════════════════════════════════ --%>

        <section id="mood-chapter-1" class="mb-24">
          <button
            type="button"
            id="mood-show-intro"
            data-show-intro
            class="text-xs uppercase tracking-widest text-gray-600 cursor-pointer hover:text-gray-400 transition-colors mb-3 inline-block"
            style="display:none"
          >
            &lsaquo; Show intro
          </button>
          <h2 class="text-sm font-semibold uppercase tracking-widest text-gray-200 mb-4">
            My mood states
          </h2>

          <p class="text-sm text-gray-400 mb-4 leading-relaxed">
            These aren't categories I picked off a list — they're shapes the data found on its own, and I named them after I could see what they looked like. The clustering doesn't care about diagnostic labels; it just notices when days look like other days, and groups them accordingly.
          </p>

          <p class="text-sm text-gray-400 mb-6 leading-relaxed">
            Run {@stats.entry_count} days through fuzzy c-means clustering and my moods fall into {@stats.cluster_count} rough shapes — not boxes, more like gravity wells a day can lean toward.
            <%= if @stats.most_common do %>
              The one I live in most is
              <span style={"color: #{Map.get(@analysis.cluster_colors, @stats.most_common.id, "#aaa")}"}>
                {@stats.most_common.name}
              </span>
              — {@stats.most_common.days} days, about {div(
                @stats.most_common.days * 100,
                max(@stats.entry_count, 1)
              )}% of everything tracked.
            <% end %>
            <%= if @stats.longest_run do %>
              My longest uninterrupted stretch was {@stats.longest_run.days} days of <span style={"color: #{Map.get(@analysis.cluster_colors, @stats.longest_run.id, "#aaa")}"}>
                {@stats.longest_run.name}</span>.
            <% end %>
            Click any state to dim everything else across the page — click it again to let everything back in.
          </p>

          <div class="flex flex-wrap items-center gap-2">
            <%= for cluster <- @analysis.clusters do %>
              <button
                phx-click="cluster_selected"
                phx-value-cluster={cluster["id"]}
                class={"inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium cursor-pointer border #{if @selected_cluster == cluster["id"], do: "ring-2 ring-offset-1 ring-offset-base-300 scale-105", else: "hover:scale-105"}"}
                style={"background: #{Map.get(@analysis.cluster_colors, cluster["id"], "#666")}#{if @selected_cluster == cluster["id"], do: "55", else: "28"}; color: #{Map.get(@analysis.cluster_colors, cluster["id"], "#aaa")}; border-color: #{Map.get(@analysis.cluster_colors, cluster["id"], "#666")}#{if @selected_cluster == cluster["id"], do: "aa", else: "55"}; #{if @selected_cluster && @selected_cluster != cluster["id"], do: "opacity:0.35", else: ""}"}
              >
                <span
                  class="inline-block w-2 h-2 rounded-full"
                  style={"background: #{Map.get(@analysis.cluster_colors, cluster["id"], "#666")}"}
                >
                </span>
                {cluster["name"]}
              </button>
            <% end %>
            <%= if @selected_cluster do %>
              <button
                phx-click="clear_highlights"
                class="text-xs text-gray-600 hover:text-gray-400 ml-1"
              >
                &times; clear
              </button>
            <% end %>
          </div>

          <div class="bg-base-200 rounded-lg p-4 mt-4">
            <div
              id="cluster-radar"
              phx-hook="ClusterRadar"
              phx-update="ignore"
              style="min-height: 180px;"
            >
            </div>
          </div>
        </section>

        <%!-- ═══════════════════════════════════════ --%>
        <%!-- CHAPTER 2: THE FULL PICTURE             --%>
        <%!-- ═══════════════════════════════════════ --%>

        <section id="mood-chapter-2" class="mb-24">
          <h2 class="text-sm font-semibold uppercase tracking-widest text-gray-200 mb-4">
            Day by day
          </h2>
          <p class="text-sm text-gray-400 mb-4 leading-relaxed">
            You can't really feel four years of mood from the inside — it's all just <em>now</em>. But pull back far enough and there's a texture to it: stripes, runs, pockets where one state pooled for weeks before something tipped it over.
          </p>
          <p class="text-sm text-gray-400 mb-6 leading-relaxed">
            Every square is a day. Color is the dominant mood state; brightness is how hard it pulled. White-bordered squares are the days when the dominant state actually changed — the meaningful hand-offs, not the day-to-day jitter.
            <%= if @stats.first_state && @stats.last_state do %>
              I started in
              <span style={"color: #{Map.get(@analysis.cluster_colors, @stats.first_state.id, "#aaa")}"}>
                {@stats.first_state.name}
              </span>
              and — for now — I'm in <span style={"color: #{Map.get(@analysis.cluster_colors, @stats.last_state.id, "#aaa")}"}>
                {@stats.last_state.name}</span>.
            <% end %>
            Drag across the strip below to zoom into a window, or click any square to see the days around it.
          </p>

          <div>
            <div
              id="temporal-brush"
              phx-hook="TemporalBrush"
              phx-update="ignore"
              style="min-height: 50px;"
            >
            </div>
            <%= if @date_range do %>
              <div class="flex items-center gap-2 mt-1">
                <span class="text-xs text-gray-500">
                  {elem(@date_range, 0)} → {elem(@date_range, 1)}
                </span>
                <button
                  phx-click="brush_changed"
                  phx-value-start=""
                  phx-value-end=""
                  class="text-xs text-gray-500 hover:text-gray-300"
                >
                  clear
                </button>
              </div>
            <% end %>
          </div>

          <div class="mt-3">
            <.live_component
              module={Calendar}
              id="calendar"
              highlighted_dates={@highlighted_dates}
              selected_gap={@selected_gap}
            />
          </div>

          <div class="bg-base-200 rounded-lg p-4 mt-4">
            <h3 class="text-sm font-semibold text-gray-400 mb-2">How my states ebb and flow</h3>
            <div
              id="cluster-stream"
              phx-hook="ClusterStream"
              phx-update="ignore"
              style="min-height: 210px;"
            >
            </div>
          </div>
        </section>

        <%!-- ═══════════════════════════════════════ --%>
        <%!-- CHAPTER 3: HOW MY MOODS SHIFT           --%>
        <%!-- ═══════════════════════════════════════ --%>

        <section id="mood-chapter-3" class="mb-24">
          <h2 class="text-sm font-semibold uppercase tracking-widest text-gray-200 mb-4">
            How my moods shift
          </h2>
          <p class="text-sm text-gray-400 mb-4 leading-relaxed">
            The interesting question isn't which state I'm in — it's the verbs. The hand-offs. What does the data tend to <em>become</em>? Some pairs are well-worn paths and some almost never happen, and the shape of those preferences says something I couldn't have named on my own.
          </p>
          <p class="text-sm text-gray-400 mb-6 leading-relaxed">
            The dominant state flipped {@stats.transition_count} times across {@stats.entry_count} days — roughly once every {div(
              @stats.entry_count,
              max(@stats.transition_count, 1)
            )} days on average. I'm only counting a hand-off when the new state holds for at least five days; anything shorter is the model arguing with itself, not me actually moving.
            <%= if @stats.biggest_flow && @stats.biggest_flow.from && @stats.biggest_flow.to do %>
              The most-worn path was
              <span style={"color: #{Map.get(@analysis.cluster_colors, @stats.biggest_flow.from.id, "#aaa")}"}>
                {@stats.biggest_flow.from.name}
              </span>
              →
              <span style={"color: #{Map.get(@analysis.cluster_colors, @stats.biggest_flow.to.id, "#aaa")}"}>
                {@stats.biggest_flow.to.name}
              </span>
              ({@stats.biggest_flow.count}×).
            <% end %>
            The timeline below turns every reign of a mood state into a colored block, with white markers at every handoff.
          </p>

          <div class="bg-base-200 rounded-lg p-4">
            <div
              id="transition-timeline"
              phx-hook="TransitionTimeline"
              phx-update="ignore"
              style="min-height: 50px;"
            >
            </div>
          </div>

          <div class="bg-base-200 rounded-lg p-4 mt-4">
            <h3 class="text-sm font-semibold text-gray-400 mb-2">Where do I go from here?</h3>
            <p class="text-xs text-gray-500 mb-3">
              Once I'm in a state, where does it tend to drop me next? Thicker bands mean a well-trodden path.
            </p>
            <div
              id="transition-sankey"
              phx-hook="TransitionSankey"
              phx-update="ignore"
              style="min-height: 320px;"
            >
            </div>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mt-4">
            <div class="bg-base-200 rounded-lg p-4 flex flex-col items-center">
              <h3 class="text-sm font-semibold text-gray-400 mb-2 self-start">
                The full web of transitions
              </h3>
              <p class="text-xs text-gray-500 mb-3 self-start">
                Same data, arranged as a loop — every pair of states and how often one becomes the other. Thicker ribbons, more traffic.
              </p>
              <div
                id="transition-chord"
                phx-hook="TransitionChord"
                phx-update="ignore"
                style="min-height: 280px;"
              >
              </div>
            </div>

            <.live_component
              module={MoodTransitions}
              id="mood-transitions-list"
              transitions={@mood_transitions}
              cluster_colors={@analysis.cluster_colors}
              cluster_names={id_to_name(@analysis.clusters)}
              selected_cluster={@selected_cluster}
            />
          </div>
        </section>

        <%!-- ═══════════════════════════════════════ --%>
        <%!-- CHAPTER 4: UNDER THE HOOD               --%>
        <%!-- ═══════════════════════════════════════ --%>

        <section class="mb-24">
          <h2 class="text-sm font-semibold uppercase tracking-widest text-gray-200 mb-4">
            Under the hood
          </h2>
          <p class="text-sm text-gray-400 mb-4 leading-relaxed">
            Up to here it's been the <em>output</em>
            of the model — the named states, how they ebb, how they hand off. This section is the <em>input</em>: the five raw numbers I rate every evening, before anything fancy happens to them. Sleep, anxiety, sensitivity, outlook, and speed, each on 0–10.
          </p>
          <p class="text-sm text-gray-400 mb-6 leading-relaxed">
            They're the only thing the clustering knows about me — every shape further up the page is downstream of them. Here's what the five actually do on their own: how they drift over time, which ones move together, and how they're spread across all {@stats.entry_count} days.
          </p>

          <div class="bg-base-200 rounded-lg p-4">
            <h3 class="text-sm font-semibold text-gray-400 mb-2">A flower for every month</h3>
            <p class="text-xs text-gray-500 mb-3">
              Each flower is one month. The shape is the average of those five raw inputs over the month — long spokes are dimensions that ran high, short ones ran low. The fill color is whichever cluster came out on top once the same numbers went through the model. Same data, two readings: the inputs you'd recognize and the output they add up to.
            </p>
            <div
              id="mood-flowers"
              phx-hook="MoodFlowers"
              phx-update="ignore"
              style="min-height: 460px;"
            >
            </div>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mt-4">
            <div class="bg-base-200 rounded-lg p-4 flex flex-col items-center">
              <h3 class="text-sm font-semibold text-gray-400 mb-2 self-start">Correlations</h3>
              <p class="text-xs text-gray-500 mb-2 self-start">
                Which of the five tend to travel together? Pink cells rise and fall in sync; cyan cells pull against each other.
              </p>
              <div
                id="correlation-heatmap"
                phx-hook="CorrelationHeatmap"
                phx-update="ignore"
                style="min-height: 250px;"
              >
              </div>
            </div>

            <div class="bg-base-200 rounded-lg p-4">
              <h3 class="text-sm font-semibold text-gray-400 mb-2">Distributions</h3>
              <p class="text-xs text-gray-500 mb-2">
                Where each dimension usually lands. The line is the median, the dot is the mean — the gap between them tells you which way the tail leans.
              </p>
              <div
                id="dimension-distributions"
                phx-hook="DimensionDistributions"
                phx-update="ignore"
                style="min-height: 230px;"
              >
              </div>
            </div>
          </div>
        </section>

        <%!-- ═══════════════════════════════════════ --%>
        <%!-- CHAPTER 5: THE GAPS                     --%>
        <%!-- ═══════════════════════════════════════ --%>

        <section id="mood-chapter-5" class="mb-24">
          <h2 class="text-sm font-semibold uppercase tracking-widest text-gray-200 mb-4">The gaps</h2>
          <p class="text-sm text-gray-400 mb-4 leading-relaxed">
            The days I didn't track are also data. Tracking is the first thing to drop when a state gets loud enough to drown out the form — so when the page goes quiet, it's almost never because nothing was happening. The gaps aren't holes in the record so much as a different kind of entry: <em>whatever this was, it was too much to write down</em>.
          </p>
          <p class="text-sm text-gray-400 mb-6 leading-relaxed">
            <%= if @stats.gap_count > 0 do %>
              I'm not perfect at this — I missed some days. There are {@stats.gap_count} stretches where I went quiet, and a lot of the time the state I came back in wasn't the state I left in. That's its own kind of signal. Click a mood state above to see which gaps touched it.
            <% else %>
              No gaps — every day in the window is accounted for.
            <% end %>
          </p>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <.live_component
              module={GapAnalysis}
              id="gaps"
              gaps={@gaps}
              cluster_colors={@analysis.cluster_colors}
              cluster_names={id_to_name(@analysis.clusters)}
              selected_cluster={@selected_cluster}
            />

            <.live_component
              module={ClusterTransitions}
              id="cluster-transitions"
              gaps={@gaps}
              cluster_colors={@analysis.cluster_colors}
              cluster_names={id_to_name(@analysis.clusters)}
              selected_cluster={@selected_cluster}
            />
          </div>
        </section>

        <%!-- ═══════════════════════════════════════ --%>
        <%!-- CHAPTER 6: AFTER                          --%>
        <%!-- ═══════════════════════════════════════ --%>

        <section class="mb-16 max-w-2xl">
          <h2 class="text-sm font-semibold uppercase tracking-widest text-gray-200 mb-4">After</h2>
          <p class="text-sm text-gray-300 mb-5 leading-relaxed">
            That's the shape of it, for now. The model will keep updating as I keep logging — come back in a few months and the picture will look different in ways neither of us can predict yet.
          </p>
          <p class="text-sm text-gray-300 mb-5 leading-relaxed">
            None of this is meant as a recommendation, or a method, or a diagnosis. It's just me trying to look at myself with a little more resolution than the language I was handed. The numbers don't replace the words for what's happening — they sit next to them, and sometimes they catch something the words miss.
          </p>
          <p class="text-sm text-gray-300 leading-relaxed">
            If you read this far, thank you. If something in here landed for you — or if you've built something like it for your own data — I'd genuinely like to hear about it.
          </p>
        </section>

        <%!-- Param controls at the very bottom — they're for tuning, not for the story --%>
        <details id="mood-param-controls" class="mt-8 mb-4">
          <summary class="text-xs uppercase tracking-widest text-gray-600 cursor-pointer hover:text-gray-400">
            Play with the math &rsaquo; clustering parameters
          </summary>
          <div class="mt-2">
            <.live_component
              module={ParamControls}
              id="params"
              k={@k}
              m={@m}
              fpc={@analysis.fpc}
              iterations={@analysis.iterations}
              cluster_count={length(@analysis.clusters)}
            />
          </div>
        </details>
      <% end %>
    </div>
    """
  end
end
