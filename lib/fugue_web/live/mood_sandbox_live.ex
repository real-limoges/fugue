defmodule FugueWeb.MoodSandboxLive do
  @moduledoc """
  Interactive sandbox for manipulating the fuzzy logic pipeline end-to-end:
  clustering parameters (k, m) and the membership functions themselves.
  Complements /mood by emphasizing the tools rather than the narrative.
  """

  use FugueWeb, :live_view

  alias FugueWeb.MoodLive.{Calendar, DataTransforms, ParamControls}
  alias FugueWeb.MoodLive.Structs.{AnalysisResult, CalendarDay, GapData}
  alias FugueWeb.MoodSandboxLive.MembershipEditor
  alias Fugue.{Ish, MembershipDefaults}

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
        analysis: %AnalysisResult{},
        gaps: nil,
        smoothed_daily: [],
        membership_defs: nil,
        histograms: %{},
        suggestion: nil,
        highlighted_dates: [],
        selected_gap: nil,
        selected_day: nil
      )

    if connected?(socket), do: send(self(), :load_all)

    {:ok, socket}
  end

  def handle_info(:load_all, socket) do
    tasks = %{
      data: Task.async(fn -> Ish.data() end),
      analysis: Task.async(fn -> Ish.cluster(@default_k, @default_m) end),
      gaps: Task.async(fn -> Ish.gaps() end),
      mf: Task.async(fn -> Ish.membership_functions() end),
      _snapshot: Task.async(fn -> MembershipDefaults.get() end)
    }

    results = Map.new(tasks, fn {key, task} -> {key, Task.await(task, 15_000)} end)

    case {results.data, results.analysis, results.gaps, results.mf} do
      {{:ok, entries}, {:ok, raw_analysis}, {:ok, raw_gaps}, {:ok, mf_defs}} ->
        analysis = DataTransforms.parse_analysis(raw_analysis, entries)

        gaps =
          raw_gaps |> GapData.from_api() |> DataTransforms.remap_gap_keys(analysis.name_to_id)

        histograms = build_histograms(entries, mf_defs)

        socket =
          socket
          |> assign(
            loading: false,
            entries: entries,
            analysis: analysis,
            gaps: gaps,
            membership_defs: mf_defs,
            histograms: histograms
          )
          |> push_cluster_viz()
          |> push_editor_data()

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
          |> assign(analysis: analysis)
          |> push_cluster_viz()

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

  def handle_event("mf_commit", %{"inputs" => new_inputs}, socket) do
    new_defs = Map.put(socket.assigns.membership_defs, "inputs", new_inputs)

    case Ish.update_membership_functions(new_defs) do
      {:ok, committed} ->
        send(self(), {:recluster, socket.assigns.k, socket.assigns.m})

        {:noreply,
         socket
         |> assign(membership_defs: committed, suggestion: nil)
         |> push_event("clear-suggestion", %{})}

      {:error, _} ->
        {:noreply, assign(socket, error: "Could not update membership functions")}
    end
  end

  def handle_event("mf_suggest", _params, socket) do
    case Ish.suggest_membership_functions() do
      {:ok, suggestion} ->
        {:noreply,
         socket
         |> assign(suggestion: suggestion)
         |> push_event("show-suggestion", %{defs: suggestion})}

      {:error, _} ->
        {:noreply, assign(socket, error: "Suggestion failed")}
    end
  end

  def handle_event("mf_apply_suggestion", _params, %{assigns: %{suggestion: nil}} = socket) do
    {:noreply, socket}
  end

  def handle_event("mf_apply_suggestion", _params, socket) do
    case Ish.update_membership_functions(socket.assigns.suggestion) do
      {:ok, committed} ->
        send(self(), {:recluster, socket.assigns.k, socket.assigns.m})

        socket =
          socket
          |> assign(
            membership_defs: committed,
            suggestion: nil,
            histograms: build_histograms(socket.assigns.entries, committed)
          )
          |> push_editor_data()
          |> push_event("clear-suggestion", %{})

        {:noreply, socket}

      {:error, _} ->
        {:noreply, assign(socket, error: "Could not apply suggestion")}
    end
  end

  def handle_event("mf_reset", _params, socket) do
    with {:ok, defaults} <- MembershipDefaults.get(),
         {:ok, committed} <- Ish.update_membership_functions(defaults) do
      send(self(), {:recluster, socket.assigns.k, socket.assigns.m})

      socket =
        socket
        |> assign(
          membership_defs: committed,
          suggestion: nil,
          histograms: build_histograms(socket.assigns.entries, committed)
        )
        |> push_editor_data()
        |> push_event("clear-suggestion", %{})

      {:noreply, socket}
    else
      _ -> {:noreply, assign(socket, error: "Could not reset membership functions")}
    end
  end

  # --- Push helpers ---

  defp push_cluster_viz(socket) do
    %{entries: entries, analysis: analysis} = socket.assigns

    smoothed_daily =
      entries
      |> DataTransforms.daily_dominants(analysis)
      |> DataTransforms.smooth_runs()

    socket
    |> assign(smoothed_daily: smoothed_daily)
    |> push_trajectory()
    |> push_calendar()
  end

  defp push_trajectory(socket) do
    %{entries: entries, analysis: analysis, smoothed_daily: daily} = socket.assigns
    points = DataTransforms.build_trajectory(entries, daily)

    push_event(socket, "update-trajectory", %{
      points: points,
      clusterColors: analysis.cluster_colors,
      clusterNames: Enum.into(analysis.clusters, %{}, fn c -> {c["id"], c["name"]} end)
    })
  end

  defp push_calendar(socket) do
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

  defp push_editor_data(socket) do
    push_event(socket, "update-membership-editor", %{
      defs: socket.assigns.membership_defs,
      histograms: socket.assigns.histograms
    })
  end

  # --- Helpers ---

  defp build_histograms(entries, %{"inputs" => inputs}) do
    bounds =
      Map.new(inputs, fn %{"name" => n, "bounds" => [lo, hi]} -> {n, {lo * 1.0, hi * 1.0}} end)

    DataTransforms.build_histograms(entries, bounds)
  end

  defp build_histograms(_, _), do: %{}

  # --- Render ---

  def render(assigns) do
    ~H"""
    <div class="mood-sandbox p-4 max-w-6xl mx-auto">
      <%= if @error do %>
        <div class="bg-red-900/50 border border-red-500 text-red-200 px-4 py-3 rounded mb-4">
          {@error}
        </div>
      <% end %>

      <%= if @loading do %>
        <div class="flex items-center justify-center h-64">
          <p class="text-gray-400 text-lg">Loading sandbox…</p>
        </div>
      <% else %>
        <header class="mb-8">
          <h1 class="text-3xl font-semibold text-gray-100 mb-3">Mood Sandbox</h1>
          <p class="text-sm text-gray-400 leading-relaxed max-w-3xl">
            <a href="/mood" class="underline hover:text-gray-200">/mood</a>
            is what I learned. This page is the tools I used to learn it. Drag things.
            Break things. The clusters and membership curves re-compute live.
          </p>
        </header>

        <section class="mb-10">
          <h2 class="text-sm font-semibold uppercase tracking-widest text-gray-200 mb-3">
            Why fuzzy for bipolar
          </h2>
          <p class="text-sm text-gray-400 leading-relaxed max-w-3xl mb-3">
            Discrete categories — manic, depressed, euthymic — lose the gradient. Most
            days aren't pure; the information lives in the blend. Fuzzy logic keeps the
            blend: every day holds partial membership in every state at once.
          </p>
          <p class="text-sm text-gray-400 leading-relaxed max-w-3xl">
            What counts as "high outlook" for a bipolar baseline sits in a different
            place than the general-population curve. The whole point of the editor below
            is that those curves have to be shaped from the data, not assumed.
          </p>
        </section>

        <section class="mb-10">
          <.live_component
            module={ParamControls}
            id="sandbox-param-controls"
            k={@k}
            m={@m}
            cluster_count={length(@analysis.clusters)}
            fpc={@analysis.fpc}
            iterations={@analysis.iterations}
          />
          <p class="text-xs text-gray-500 mt-2 max-w-3xl">
            k sets how many states to find. m is fuzziness — higher m means days belong
            to more states at once. Both re-run clustering on every change.
          </p>

          <div class="flex flex-wrap gap-2 mt-3">
            <%= for cluster <- @analysis.clusters do %>
              <span
                class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-medium border"
                style={"border-color: #{Map.get(@analysis.cluster_colors, cluster["id"], "#666")}; color: #{Map.get(@analysis.cluster_colors, cluster["id"], "#ccc")}"}
              >
                <span
                  class="w-2 h-2 rounded-full"
                  style={"background: #{Map.get(@analysis.cluster_colors, cluster["id"], "#666")}"}
                >
                </span>
                {cluster["name"]}
              </span>
            <% end %>
          </div>
        </section>

        <section class="mb-10">
          <.live_component
            module={MembershipEditor}
            id="membership-editor"
            defs={@membership_defs}
            histograms={@histograms}
            suggestion={@suggestion}
          />
        </section>

        <section class="mb-10">
          <h2 class="text-sm font-semibold uppercase tracking-widest text-gray-200 mb-3">
            Downstream effects
          </h2>
          <p class="text-xs text-gray-500 mb-4 max-w-3xl">
            These re-compute whenever you touch a slider or reshape a curve. Same visuals
            as /mood — same data, different fuzzy lens.
          </p>

          <div class="bg-base-200 rounded-lg p-4 mb-4">
            <h3 class="text-sm font-semibold text-gray-400 mb-2">Trajectory</h3>
            <div
              id="sandbox-trajectory"
              phx-hook="MoodTrajectory"
              phx-update="ignore"
              style="min-height: 520px;"
            >
            </div>
          </div>

          <.live_component
            module={Calendar}
            id="sandbox-calendar"
            highlighted_dates={@highlighted_dates}
            selected_gap={@selected_gap}
          />
        </section>

        <footer class="mt-16 pb-8 text-xs text-gray-500">
          <p>
            Editing membership functions here affects <a href="/mood" class="underline">/mood</a>
            too — Ish holds one global fuzzy system. Reset to defaults before you leave if
            you want /mood back to its narrative shape.
          </p>
        </footer>
      <% end %>
    </div>
    """
  end
end
