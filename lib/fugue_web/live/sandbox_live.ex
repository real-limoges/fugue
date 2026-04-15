defmodule FugueWeb.SandboxLive do
  @moduledoc """
  Math exploration playground. Each experiment on the page stands on its own —
  poke at parameters, watch the model respond. Currently hosts a fuzzy
  clustering experiment (k, m, membership-function editor). More experiments
  will land here over time; the page is structured to let them coexist rather
  than assume one owns the surface.
  """

  use FugueWeb, :live_view

  alias FugueWeb.MoodLive.{DataTransforms, ParamControls}
  alias FugueWeb.MoodLive.Structs.{AnalysisResult, GapData}
  alias FugueWeb.SandboxLive.MembershipEditor
  alias Fugue.{Ish, MembershipDefaults}

  @default_k 3
  @default_m 1.5
  @history_limit 20
  @presets ~w(conservative aggressive chaos randomize)

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
        smoothed_daily: [],
        membership_defs: nil,
        histograms: %{},
        suggestion: nil,
        history: []
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

    if k == socket.assigns.k and m == socket.assigns.m do
      {:noreply, socket}
    else
      socket = socket |> push_history() |> assign(k: k, m: m)
      send(self(), {:recluster, k, m})
      {:noreply, socket}
    end
  end

  def handle_event("mf_commit", %{"inputs" => new_inputs}, socket) do
    new_defs = Map.put(socket.assigns.membership_defs, "inputs", new_inputs)

    case Ish.update_membership_functions(new_defs) do
      {:ok, committed} ->
        send(self(), {:recluster, socket.assigns.k, socket.assigns.m})

        {:noreply,
         socket
         |> push_history()
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
          |> push_history()
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
        |> push_history()
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

  def handle_event("apply_preset", %{"name" => name}, socket) when name in @presets do
    {k, m, new_defs} = preset_config(name, socket.assigns.membership_defs)

    case Ish.update_membership_functions(new_defs) do
      {:ok, committed} ->
        send(self(), {:recluster, k, m})

        socket =
          socket
          |> push_history()
          |> assign(
            k: k,
            m: m,
            membership_defs: committed,
            suggestion: nil,
            histograms: build_histograms(socket.assigns.entries, committed)
          )
          |> push_editor_data()
          |> push_event("clear-suggestion", %{})

        {:noreply, socket}

      {:error, _} ->
        {:noreply, assign(socket, error: "Could not apply preset")}
    end
  end

  def handle_event("undo", _params, %{assigns: %{history: []}} = socket) do
    {:noreply, socket}
  end

  def handle_event("undo", _params, socket) do
    [snapshot | rest] = socket.assigns.history
    %{k: k, m: m, membership_defs: old_defs} = snapshot

    case Ish.update_membership_functions(old_defs) do
      {:ok, committed} ->
        send(self(), {:recluster, k, m})

        socket =
          socket
          |> assign(
            k: k,
            m: m,
            membership_defs: committed,
            suggestion: nil,
            history: rest,
            histograms: build_histograms(socket.assigns.entries, committed)
          )
          |> push_editor_data()
          |> push_event("clear-suggestion", %{})

        {:noreply, socket}

      {:error, _} ->
        {:noreply, assign(socket, error: "Could not undo")}
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
    |> push_stream()
  end

  defp push_stream(socket) do
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
    cluster_names = Enum.into(analysis.clusters, %{}, fn c -> {c["id"], c["name"]} end)

    push_event(socket, "update-stream", %{
      series: series,
      clusterColors: analysis.cluster_colors,
      clusterIds: cluster_ids,
      clusterNames: cluster_names
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

  defp format_fpc(nil), do: "—"
  defp format_fpc(fpc) when is_number(fpc), do: :erlang.float_to_binary(fpc * 1.0, decimals: 3)

  defp fpc_pct(nil, _k), do: 0

  defp fpc_pct(fpc, k) when is_number(fpc) and is_integer(k) and k > 1 do
    floor = 1.0 / k
    pct = (fpc - floor) / (1.0 - floor) * 100
    pct |> max(0) |> min(100) |> Float.round(1)
  end

  defp fpc_pct(_, _), do: 0

  defp push_history(socket) do
    snapshot = %{
      k: socket.assigns.k,
      m: socket.assigns.m,
      membership_defs: socket.assigns.membership_defs
    }

    history = [snapshot | socket.assigns.history] |> Enum.take(@history_limit)
    assign(socket, history: history)
  end

  # --- Presets ---

  defp preset_config("conservative", defs), do: {2, 1.2, reshape_mf(defs, :tight)}
  defp preset_config("aggressive", defs), do: {5, 1.8, reshape_mf(defs, :wide)}
  defp preset_config("chaos", defs), do: {5, 2.8, reshape_mf(defs, :wide)}

  defp preset_config("randomize", defs) do
    k = Enum.random(2..5)
    m = (12 + :rand.uniform(14)) / 10.0
    {k, m, reshape_mf(defs, :random)}
  end

  defp reshape_mf(%{"inputs" => inputs} = defs, shape) do
    Map.put(defs, "inputs", Enum.map(inputs, &reshape_var(&1, shape)))
  end

  defp reshape_var(%{"bounds" => [lo, hi]} = var, shape) do
    Map.put(var, "terms", triangle_terms(shape, lo * 1.0, (hi - lo) * 1.0))
  end

  defp triangle_terms(:tight, lo, range) do
    [
      %{"name" => "low", "params" => [lo, lo, lo + 0.25 * range]},
      %{"name" => "medium", "params" => [lo + 0.35 * range, lo + 0.5 * range, lo + 0.65 * range]},
      %{"name" => "high", "params" => [lo + 0.75 * range, lo + range, lo + range]}
    ]
  end

  defp triangle_terms(:wide, lo, range) do
    [
      %{"name" => "low", "params" => [lo, lo + 0.15 * range, lo + 0.55 * range]},
      %{"name" => "medium", "params" => [lo + 0.15 * range, lo + 0.5 * range, lo + 0.85 * range]},
      %{"name" => "high", "params" => [lo + 0.45 * range, lo + 0.85 * range, lo + range]}
    ]
  end

  defp triangle_terms(:random, lo, range) do
    low_peak = lo + :rand.uniform() * 0.35 * range
    mid_peak = lo + (0.35 + :rand.uniform() * 0.3) * range
    high_peak = lo + (0.65 + :rand.uniform() * 0.35) * range

    [
      %{"name" => "low", "params" => [lo, low_peak, mid_peak]},
      %{"name" => "medium", "params" => [low_peak, mid_peak, high_peak]},
      %{"name" => "high", "params" => [mid_peak, high_peak, lo + range]}
    ]
  end

  # --- Render ---

  def render(assigns) do
    ~H"""
    <div class="sandbox-page p-4 max-w-6xl mx-auto">
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
        <header class="mb-12">
          <.link
            navigate="/mood"
            class="text-xs uppercase tracking-widest text-gray-500 hover:text-gray-300 transition-colors mb-3 inline-block"
          >
            &lsaquo; Back to /mood
          </.link>
          <h1 class="text-3xl font-semibold text-gray-100 mb-3">Sandbox</h1>
          <p class="text-sm text-gray-400 leading-relaxed max-w-3xl">
            A place to push on math. Each experiment below stands on its own —
            drag the parameters, swap the shapes, watch what the model does
            differently. There's no narrative tying them together; they're here
            because they're fun to poke at.
          </p>
        </header>

        <section class="mb-16 pb-12 border-b border-white/5">
          <header class="mb-6">
            <p class="text-[10px] uppercase tracking-[0.2em] text-gray-500 mb-2">Experiment</p>
            <h2 class="text-2xl font-semibold text-gray-100 mb-3">Fuzzy clustering</h2>
            <p class="text-sm text-gray-400 leading-relaxed max-w-3xl mb-3">
              Hard categories lose the gradient. Most points aren't pure — the
              information lives in the blend. Fuzzy logic keeps the blend: every point
              holds partial membership in every cluster at once.
            </p>
            <p class="text-sm text-gray-400 leading-relaxed max-w-3xl">
              The editor below reshapes what counts as <em>low</em>, <em>medium</em>,
              or <em>high</em> on each input dimension. Those curves have to be shaped
              from the data, not assumed — and the clusters re-compute live as you
              touch them.
            </p>
          </header>

          <div class="mb-10">
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
              k sets how many clusters to find. m is fuzziness — higher m means points
              belong to more clusters at once. Both re-run clustering on every change.
            </p>

            <div class="flex flex-wrap items-center gap-2 mt-4">
              <span class="text-xs uppercase tracking-wider text-gray-500 mr-1">Presets:</span>
              <button
                type="button"
                phx-click="apply_preset"
                phx-value-name="conservative"
                class="btn btn-xs btn-outline"
              >
                Conservative
              </button>
              <button
                type="button"
                phx-click="apply_preset"
                phx-value-name="aggressive"
                class="btn btn-xs btn-outline"
              >
                Aggressive
              </button>
              <button
                type="button"
                phx-click="apply_preset"
                phx-value-name="chaos"
                class="btn btn-xs btn-outline"
              >
                Chaos
              </button>
              <button
                type="button"
                phx-click="apply_preset"
                phx-value-name="randomize"
                class="btn btn-xs btn-outline"
              >
                Randomize
              </button>
              <div class="grow"></div>
              <button
                type="button"
                phx-click="undo"
                disabled={@history == []}
                class="btn btn-xs btn-ghost"
              >
                Undo<span :if={@history != []} class="opacity-60 ml-1">({length(@history)})</span>
              </button>
            </div>

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
          </div>

          <div class="mb-10">
            <.live_component
              module={MembershipEditor}
              id="membership-editor"
              defs={@membership_defs}
              histograms={@histograms}
              suggestion={@suggestion}
            />
          </div>

          <div class="mb-6">
            <h3 class="text-sm font-semibold uppercase tracking-widest text-gray-200 mb-3">
              Downstream effects
            </h3>
            <p class="text-xs text-gray-500 mb-4 max-w-3xl">
              This re-computes whenever you touch a slider or reshape a curve — the
              same input points seen through whatever fuzzy lens you're building above.
            </p>

            <div class="bg-base-200 rounded-lg p-4 mb-4">
              <div class="flex items-baseline justify-between mb-2">
                <h4 class="text-xs uppercase tracking-widest text-gray-500">
                  Cluster crispness (FPC)
                </h4>
                <span class="text-xs text-gray-500 font-mono">
                  floor 1/k = {Float.round(1.0 / max(@k, 1), 3)} · ceiling 1.0
                </span>
              </div>
              <div class="flex items-center gap-4">
                <div class="text-4xl font-semibold tabular-nums text-amber-300 w-28">
                  {format_fpc(@analysis.fpc)}
                </div>
                <div class="flex-1">
                  <div class="h-3 w-full bg-base-300 rounded-full overflow-hidden relative">
                    <div
                      class="h-full bg-amber-400 transition-all duration-300 ease-out"
                      style={"width: #{fpc_pct(@analysis.fpc, @k)}%"}
                    >
                    </div>
                  </div>
                  <p class="text-xs text-gray-500 mt-2 leading-snug">
                    1.0 means every point belongs cleanly to one cluster. 1/k is the
                    worst case — every point split evenly across all clusters. Lower m
                    and tighter curves push it up; higher m and wider curves push it down.
                  </p>
                </div>
              </div>
            </div>

            <div class="bg-base-200 rounded-lg p-4">
              <h4 class="text-sm font-semibold text-gray-400 mb-2">Cluster memberships over time</h4>
              <div
                id="sandbox-cluster-stream"
                phx-hook="ClusterStream"
                phx-update="ignore"
                style="min-height: 210px;"
              >
              </div>
            </div>
          </div>

          <p class="text-xs text-gray-500 mt-8 max-w-3xl leading-snug">
            Heads up: the membership functions you edit here are stored globally —
            Ish holds one fuzzy system at a time, so changes here persist for any
            other page that reads from it. Hit reset before you leave if you want
            the defaults back.
          </p>
        </section>
      <% end %>
    </div>
    """
  end
end
