defmodule FugueWeb.MenagerieLive.Sandpile do
  use FugueWeb, :live_view

  @speed_min 1
  @speed_max 200
  @defaults %{"mode" => "center", "speed" => 10}

  def mount(_params, _session, socket) do
    {:ok, assign(socket, params: @defaults)}
  end

  def handle_event("set_mode", %{"mode" => mode}, socket) when mode in ["center", "random"] do
    new_params = Map.put(socket.assigns.params, "mode", mode)

    {:noreply,
     socket
     |> assign(:params, new_params)
     |> push_event("sandpile:set_mode", %{mode: mode})}
  end

  def handle_event("update_speed", %{"speed" => raw}, socket) do
    speed =
      case Integer.parse(raw) do
        {val, _} -> val |> max(@speed_min) |> min(@speed_max)
        :error -> socket.assigns.params["speed"]
      end

    new_params = Map.put(socket.assigns.params, "speed", speed)

    {:noreply,
     socket
     |> assign(:params, new_params)
     |> push_event("sandpile:set_speed", %{speed: speed})}
  end

  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> assign(:params, @defaults)
     |> push_event("sandpile:reset", %{mode: @defaults["mode"], speed: @defaults["speed"]})}
  end

  def render(assigns) do
    assigns = assign(assigns, speed_min: @speed_min, speed_max: @speed_max)

    ~H"""
    <div class="sandpile-menagerie p-4 max-w-6xl mx-auto">
      <nav class="mb-6 text-xs">
        <.link navigate={~p"/menagerie"} class="text-gray-500 hover:text-gray-300">
          ← Menagerie
        </.link>
      </nav>

      <div class="mb-4">
        <h1 class="text-2xl font-bold text-gray-100">Abelian sandpile</h1>
        <p class="text-sm text-gray-400 mt-1 max-w-3xl leading-relaxed">
          Drop grains one at a time. When a cell reaches four it topples,
          sending one grain to each neighbor. The cascade can be tiny or
          enormous — and over time the system tunes itself to a critical state
          where avalanche sizes follow a power law. Nobody sets that up; it
          just happens. Click anywhere on the grid to drop a grain by hand.
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
          >
          </canvas>
        </div>

        <div class="space-y-4">
          <div class="bg-base-200 rounded-lg p-4">
            <div class="flex items-center justify-between mb-3">
              <span class="text-xs font-semibold text-gray-300">Drop mode</span>
              <span class="text-xs font-mono text-gray-400">{@params["mode"]}</span>
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

          <form phx-change="update_speed" class="bg-base-200 rounded-lg p-4">
            <div class="flex items-center justify-between mb-1">
              <span class="text-xs font-semibold text-gray-300">Grains per frame</span>
              <span class="text-xs font-mono text-gray-400">{@params["speed"]}</span>
            </div>
            <input
              type="range"
              name="speed"
              min={@speed_min}
              max={@speed_max}
              step="1"
              value={@params["speed"]}
              class="range range-xs range-primary"
            />
          </form>

          <div class="bg-base-200 rounded-lg p-4">
            <div class="flex items-center justify-between mb-1">
              <span class="text-xs font-semibold text-gray-300">Total grains</span>
              <span id="sandpile-grain-count" class="text-xs font-mono text-gray-400">0</span>
            </div>
          </div>

          <div class="bg-base-200 rounded-lg p-4">
            <div class="mb-2">
              <span class="text-xs font-semibold text-gray-300">Avalanche sizes</span>
              <span class="text-[10px] text-gray-500 ml-1">(log–log)</span>
            </div>
            <div id="sandpile-histogram" phx-update="ignore"></div>
          </div>

          <button type="button" phx-click="reset" class="btn btn-xs btn-ghost w-full">
            Reset
          </button>
        </div>
      </div>
    </div>
    """
  end
end
