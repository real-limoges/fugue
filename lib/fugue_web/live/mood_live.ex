defmodule FugueWeb.MoodLive do
  use FugueWeb, :live_view

  alias FugueWeb.MoodLive.{Calendar, ScatterPlot, GapAnalysis, ParamControls}
  alias FugueWeb.MoodLive.Structs.{AnalysisResult, CalendarDay, ScatterPoint, GapData}
  alias Fugue.Ish

  @default_k 3
  @default_m 2.0
  # Synthwave palette — matches the app's oklch theme hues
  @cluster_colors ~w(#e44dbc #42c8e6 #6ee64d #e6a542 #a86ee6 #e6e042 #e6425a #42e6b8)

  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        k: @default_k,
        m: @default_m,
        loading: true,
        error: nil,
        entries: [],
        analysis: %AnalysisResult{},
        gaps: nil,
        scatter_x: "sleep",
        scatter_y: "anxiety",
        highlighted_dates: [],
        selected_gap: nil,
        selected_cluster: nil,
        date_range: nil
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
        analysis = parse_analysis(raw_analysis)

        gaps = raw_gaps |> GapData.from_api() |> remap_gap_keys(analysis.name_to_id)

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
        analysis = parse_analysis(raw)

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

  def handle_event("update_x_axis", %{"value" => value}, socket) do
    socket =
      socket
      |> assign(:scatter_x, value)
      |> push_scatter_data()

    {:noreply, socket}
  end

  def handle_event("update_y_axis", %{"value" => value}, socket) do
    socket =
      socket
      |> assign(:scatter_y, value)
      |> push_scatter_data()

    {:noreply, socket}
  end

  def handle_event("day_selected", %{"date" => date}, socket) do
    {:noreply,
     socket
     |> assign(highlighted_dates: [date], selected_gap: nil)
     |> push_event("highlight-calendar", %{dates: [date]})
     |> push_event("highlight-scatter", %{dates: [date]})}
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
    surrounding = gap_surrounding_dates(start, len)

    {:noreply,
     socket
     |> assign(selected_gap: gap, highlighted_dates: [])
     |> push_event("highlight-calendar-gap", %{start: start, length: len})
     |> push_event("highlight-scatter", %{dates: surrounding})}
  end

  def handle_event("clear_highlights", _params, socket) do
    {:noreply,
     socket
     |> assign(highlighted_dates: [], selected_gap: nil, selected_cluster: nil)
     |> push_event("highlight-calendar", %{dates: []})
     |> push_event("highlight-scatter", %{dates: []})
     |> push_event("isolate-cluster", %{cluster: nil})}
  end

  def handle_event("cluster_selected", %{"cluster" => cluster}, socket) do
    selected = if socket.assigns.selected_cluster == cluster, do: nil, else: cluster

    socket =
      socket
      |> assign(selected_cluster: selected, highlighted_dates: [], selected_gap: nil)
      |> push_event("isolate-cluster", %{cluster: selected})
      |> push_gap_data_for_cluster(selected)

    {:noreply, socket}
  end

  def handle_event("brush_changed", %{"start" => start, "end" => end_date}, socket)
      when is_binary(start) and start != "" and is_binary(end_date) and end_date != "" do
    range = {start, end_date}

    socket =
      socket
      |> assign(date_range: range, highlighted_dates: [], selected_gap: nil)
      |> push_scatter_data()
      |> push_event("highlight-calendar", %{dates: dates_in_range(socket.assigns.entries, range)})

    {:noreply, socket}
  end

  def handle_event("brush_changed", _params, socket) do
    socket =
      socket
      |> assign(date_range: nil, highlighted_dates: [])
      |> push_scatter_data()
      |> push_event("highlight-calendar", %{dates: []})
      |> push_event("clear-brush", %{})

    {:noreply, socket}
  end

  # --- Data transforms ---

  defp parse_analysis(raw) do
    clusters =
      (raw["clusters"] || [])
      |> Enum.with_index()
      |> Enum.map(fn {c, i} -> Map.put(c, "id", "cluster_#{i}") end)

    name_to_id =
      Enum.into(clusters, %{}, fn c -> {c["name"], c["id"]} end)

    %AnalysisResult{
      clusters: clusters,
      membership: raw["membership"] || [],
      cluster_colors: build_cluster_colors(clusters),
      name_to_id: name_to_id,
      fpc: raw["fpc"],
      iterations: raw["iterations"]
    }
  end

  defp build_memberships(row, clusters) when is_list(row) do
    clusters
    |> Enum.with_index()
    |> Enum.into(%{}, fn {c, i} -> {c["id"], Enum.at(row, i, 0)} end)
  end

  defp build_memberships(_, _), do: %{}

  defp remap_gap_keys(nil, _mapping), do: nil

  defp remap_gap_keys(%GapData{} = gaps, mapping) do
    %GapData{
      transitions:
        Enum.map(gaps.transitions, fn t ->
          t
          |> Map.update("before", %{}, &remap_keys(&1, mapping))
          |> Map.update("after", %{}, &remap_keys(&1, mapping))
        end),
      length_distribution: gaps.length_distribution,
      imputed_memberships:
        Map.new(gaps.imputed_memberships, fn {date, mems} ->
          {date, remap_keys(mems, mapping)}
        end)
    }
  end

  defp remap_keys(map, mapping) when is_map(map) do
    Map.new(map, fn {k, v} -> {Map.get(mapping, k, k), v} end)
  end

  defp remap_keys(other, _mapping), do: other

  defp build_cluster_colors(clusters) do
    clusters
    |> Enum.with_index()
    |> Enum.into(%{}, fn {c, i} ->
      {c["id"], Enum.at(@cluster_colors, rem(i, length(@cluster_colors)))}
    end)
  end

  # --- Push helpers ---

  defp push_viz_data(socket) do
    socket
    |> push_calendar_data()
    |> push_scatter_data()
    |> push_gap_data()
    |> push_brush_data()
    |> push_event("highlight-calendar", %{dates: []})
    |> push_event("highlight-scatter", %{dates: []})
    |> push_event("isolate-cluster", %{cluster: nil})
  end

  defp push_calendar_data(socket) do
    %{entries: entries, analysis: analysis, gaps: gaps} = socket.assigns
    days = build_calendar_days(entries, analysis, gaps)

    push_event(socket, "update-calendar", %{
      days: Enum.map(days, &CalendarDay.to_event/1),
      clusterColors: analysis.cluster_colors
    })
  end

  defp push_scatter_data(socket) do
    %{entries: entries, analysis: analysis} = socket.assigns
    points = build_scatter_points(entries, analysis)

    filtered =
      case socket.assigns.date_range do
        {start, end_date} ->
          Enum.filter(points, fn p -> p.date >= start and p.date <= end_date end)

        _ ->
          points
      end

    push_event(socket, "update-scatter", %{
      points: Enum.map(filtered, &ScatterPoint.to_event/1),
      xAxis: socket.assigns.scatter_x,
      yAxis: socket.assigns.scatter_y,
      clusterColors: analysis.cluster_colors
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

  # --- Builders ---

  defp build_calendar_days(entries, %AnalysisResult{} = analysis, gaps) do
    imputed = if gaps, do: gaps.imputed_memberships, else: %{}

    entry_map =
      entries
      |> Enum.with_index()
      |> Enum.into(%{}, fn {entry, idx} ->
        mems = build_memberships(Enum.at(analysis.membership, idx), analysis.clusters)
        {entry["date"], %{dimensions: entry["dimensions"], memberships: mems}}
      end)

    dates = Map.keys(entry_map) ++ Map.keys(imputed)

    case dates do
      [] ->
        []

      _ ->
        min_date = Enum.min(dates)
        max_date = Enum.max(dates)

        Date.range(Date.from_iso8601!(min_date), Date.from_iso8601!(max_date))
        |> Enum.map(fn date ->
          ds = Date.to_iso8601(date)

          case Map.get(entry_map, ds) do
            nil ->
              %CalendarDay{
                date: ds,
                dimensions: nil,
                memberships: Map.get(imputed, ds, %{}),
                is_gap: true
              }

            %{dimensions: dims, memberships: mems} ->
              %CalendarDay{
                date: ds,
                dimensions: dims,
                memberships: mems,
                is_gap: false
              }
          end
        end)
    end
  end

  defp build_scatter_points(entries, %AnalysisResult{} = analysis) do
    entries
    |> Enum.with_index()
    |> Enum.map(fn {entry, idx} ->
      mems = build_memberships(Enum.at(analysis.membership, idx), analysis.clusters)

      %ScatterPoint{
        date: entry["date"],
        values: entry["dimensions"],
        memberships: mems
      }
    end)
  end

  # --- Helpers ---

  defp gap_surrounding_dates(start, length) do
    start_date = Date.from_iso8601!(start)
    before = Date.add(start_date, -1) |> Date.to_iso8601()
    after_date = Date.add(start_date, length) |> Date.to_iso8601()
    [before, after_date]
  end

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
    ~H"""
    <div class="mood-explorer p-4">
      <h1 class="text-2xl font-bold mb-4">Mood Explorer</h1>

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
        <.live_component
          module={ParamControls}
          id="params"
          k={@k}
          m={@m}
          fpc={@analysis.fpc}
          iterations={@analysis.iterations}
          cluster_count={length(@analysis.clusters)}
        />

        <div class="flex flex-wrap items-center gap-2 mt-4">
          <span class="text-sm text-gray-400">Clusters:</span>
          <%= for cluster <- @analysis.clusters do %>
            <button
              phx-click="cluster_selected"
              phx-value-cluster={cluster["id"]}
              class={"px-3 py-1 rounded-full text-xs font-medium transition-all cursor-pointer border #{if @selected_cluster == cluster["id"], do: "ring-2 ring-white ring-offset-1 ring-offset-black scale-110", else: "opacity-70 hover:opacity-100"}"}
              style={"background: #{Map.get(@analysis.cluster_colors, cluster["id"], "#666")}44; color: #{Map.get(@analysis.cluster_colors, cluster["id"], "#aaa")}; border-color: #{Map.get(@analysis.cluster_colors, cluster["id"], "#666")}88"}
            >
              {cluster["name"]}
            </button>
          <% end %>
          <%= if @selected_cluster do %>
            <button
              phx-click="cluster_selected"
              phx-value-cluster={@selected_cluster}
              class="text-xs text-gray-500 hover:text-gray-300 ml-1"
            >
              clear
            </button>
          <% end %>
        </div>

        <div class="mt-4">
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

        <div class="mt-4">
          <.live_component
            module={Calendar}
            id="calendar"
            highlighted_dates={@highlighted_dates}
            selected_gap={@selected_gap}
          />
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mt-6">
          <.live_component
            module={ScatterPlot}
            id="scatter"
            scatter_x={@scatter_x}
            scatter_y={@scatter_y}
            clusters={@analysis.clusters}
          />

          <.live_component
            module={GapAnalysis}
            id="gaps"
            gaps={@gaps}
            cluster_colors={@analysis.cluster_colors}
            cluster_names={id_to_name(@analysis.clusters)}
            selected_cluster={@selected_cluster}
          />
        </div>
      <% end %>
    </div>
    """
  end
end
