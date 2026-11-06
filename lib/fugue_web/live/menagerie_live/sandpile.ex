defmodule FugueWeb.MenagerieLive.Sandpile do
  @moduledoc """
  `/menagerie/sandpile`: Bak-Tang-Wiesenfeld self-organized criticality.
  The simulation runs JS-side in `assets/js/hooks/sandpile_canvas.js`;
  this LiveView only owns the parameter UI (mode, speed, reset) and
  pushes events to the hook. No simulation state is held server-side.
  """
  use FugueWeb, :live_view

  alias FugueWeb.MenagerieLive.AnimatedCard
  alias FugueWeb.MenagerieLive.AnimatedCard.Slider

  @defaults %{"mode" => "center", "speed" => 10}

  @sliders [
    Slider.new(
      key: "speed",
      label: "Grains per frame",
      min: 1,
      max: 200,
      step: 1,
      cast: &trunc/1,
      format: &Integer.to_string/1
    )
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, params: @defaults, sliders: @sliders)}
  end

  @impl true
  def handle_event("set_mode", %{"mode" => mode}, socket) when mode in ["center", "random"] do
    new_params = Map.put(socket.assigns.params, "mode", mode)

    {:noreply,
     socket
     |> assign(:params, new_params)
     |> push_event("sandpile:set_mode", %{mode: mode})}
  end

  def handle_event("update_params", form, socket) do
    AnimatedCard.handle_update_params(form, socket, @sliders, "sandpile:set_params")
  end

  def handle_event("reset", _params, socket) do
    AnimatedCard.handle_reset(socket, @defaults, "sandpile:reset")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="sandpile-menagerie p-4 max-w-6xl mx-auto">
      <nav class="mb-6 text-xs">
        <.link navigate={~p"/menagerie"} class="text-base-content/45 hover:text-base-content/75">
          ← Menagerie
        </.link>
      </nav>

      <div class="mb-4">
        <h1 class="text-2xl font-bold text-base-content">Abelian sandpile</h1>
        <p class="text-sm text-base-content/60 mt-1 max-w-3xl leading-relaxed">
          OK so, every cell holds some sand. Drop a grain, and when a cell gets
          to four it tips over, one grain to each neighbor, and those neighbors
          might tip over too. Most drops do nothing at all; every so often one
          grain sets off half the grid. Nobody tuned it to do that, the pile
          drifts there on its own and then sits right at the edge (physicists
          call this self-organized criticality, which is a long way of saying
          it keeps almost falling over). The histogram is avalanche sizes on a
          log-log scale, and give it a while (or crank the grains per frame)
          and it straightens out into a line. Click the grid to drop grains
          yourself.
        </p>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-[1fr_320px] gap-4">
        <div class="bg-base-200 rounded-lg overflow-hidden">
          <canvas
            id="menagerie-sandpile-canvas"
            phx-hook="SandpileCanvas"
            phx-update="ignore"
            class="block w-full cursor-crosshair"
            style="height: 512px;"
          ></canvas>
          <.figure_source
            note="Abelian sandpile: drop a grain, and any cell reaching 4 topples one grain to each neighbor, cascading until stable. The avalanche sizes go power-law without anyone tuning them there."
            repo="petri"
          />
        </div>

        <div class="space-y-4">
          <div class="bg-base-200 rounded-lg p-4">
            <div class="flex items-center justify-between mb-3">
              <span class="text-xs font-semibold text-base-content/75">Drop mode</span>
              <span class="text-xs font-mono text-base-content/60">{@params["mode"]}</span>
            </div>
            <div class="flex gap-2">
              <button
                type="button"
                phx-click="set_mode"
                phx-value-mode="center"
                class={"btn btn-xs #{if @params["mode"] == "center", do: "btn-primary", else: "btn-outline"}"}
              >
                Center
              </button>
              <button
                type="button"
                phx-click="set_mode"
                phx-value-mode="random"
                class={"btn btn-xs #{if @params["mode"] == "random", do: "btn-primary", else: "btn-outline"}"}
              >
                Random rain
              </button>
            </div>
          </div>

          <AnimatedCard.slider_grid sliders={@sliders} params={@params} class="" />

          <div class="bg-base-200 rounded-lg p-4">
            <div class="flex items-center justify-between mb-1">
              <span class="text-xs font-semibold text-base-content/75">Total grains</span>
              <span id="sandpile-grain-count" class="text-xs font-mono text-base-content/60">0</span>
            </div>
          </div>

          <div class="bg-base-200 rounded-lg p-4">
            <div class="mb-2">
              <span class="text-xs font-semibold text-base-content/75">Avalanche sizes</span>
              <span class="text-[10px] text-base-content/45 ml-1">(log-log)</span>
            </div>
            <div id="sandpile-histogram" phx-update="ignore"></div>
          </div>

          <button type="button" phx-click="reset" class="btn btn-xs btn-ghost w-full">
            Reset
          </button>
        </div>
      </div>

      <.source_link repos={["petri", {"fugue", "lib/fugue_web/live/menagerie_live/sandpile.ex"}]} />
    </div>
    """
  end
end
