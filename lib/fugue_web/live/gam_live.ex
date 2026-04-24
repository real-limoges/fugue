defmodule FugueWeb.GamLive do
  use FugueWeb, :live_view

  @layers ~w(linear gam gamlss)

  def mount(_params, _session, socket) do
    {:ok, assign(socket, layers: %{"linear" => false, "gam" => false, "gamlss" => false})}
  end

  def handle_event("toggle_layer", %{"layer" => layer}, socket) when layer in @layers do
    layers = Map.update!(socket.assigns.layers, layer, &(!&1))
    {:noreply, socket |> assign(:layers, layers) |> push_event("gam:set_layers", layers)}
  end

  def render(assigns) do
    ~H"""
    <div class="p-6 max-w-4xl mx-auto">
      <h1 class="text-2xl font-semibold text-white mb-1">Reaction Time &amp; Age</h1>
      <p class="text-gray-400 text-sm mb-6">
        Simple reaction time data across the lifespan, fit three ways.
        Each layer adds something a straight line cannot say.
      </p>

      <div
        id="gam-viz"
        phx-hook="GamDemo"
        phx-update="ignore"
        class="w-full rounded-lg bg-base-200"
        style="min-height: 420px;"
      />

      <div class="mt-4 flex flex-wrap gap-3">
        <button
          phx-click="toggle_layer"
          phx-value-layer="linear"
          class={[
            "btn btn-sm btn-ghost border",
            (@layers["linear"] && "border-white/40 text-white") || "border-white/10 text-gray-600"
          ]}
        >
          — Linear
        </button>
        <button
          phx-click="toggle_layer"
          phx-value-layer="gam"
          class={[
            "btn btn-sm btn-ghost border",
            (@layers["gam"] && "border-gray-400 text-gray-400") || "border-white/10 text-gray-600"
          ]}
        >
          ⌇ GAM (Gaussian)
        </button>
        <button
          phx-click="toggle_layer"
          phx-value-layer="gamlss"
          class={[
            "btn btn-sm btn-ghost border",
            (@layers["gamlss"] && "border-primary/60 text-primary") || "border-white/10 text-gray-600"
          ]}
        >
          ◈ GAMLSS (Gamma)
        </button>
      </div>

      <div class="mt-5 space-y-1 text-xs text-gray-500 font-mono">
        <p>
          <span class="text-white/40">—</span>
          Linear regression assumes a straight line and misses the curve entirely.
        </p>
        <p>
          <span class="text-gray-400">⌇</span>
          A Gaussian GAM finds the nonlinear shape — minimum around age 24 — but assumes spread is constant at every age. The gray band stays flat.
        </p>
        <p>
          <span class="text-primary/70">◈</span>
          Gamma GAMLSS lets spread vary too. The orange band widens with age because the Gamma distribution ties variance to the mean — older reaction times don't just slow down, they scatter more.
        </p>
      </div>
    </div>
    """
  end
end
