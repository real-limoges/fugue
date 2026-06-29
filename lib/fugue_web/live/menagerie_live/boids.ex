defmodule FugueWeb.MenagerieLive.Boids do
  @moduledoc """
  `/menagerie/boids`: flocking sim. Doubles as the site splash and
  is settled; see `lib/fugue_web/live/menagerie_live/CLAUDE.md` before
  proposing changes. Simulation runs in petri WASM via the
  `BoidsCanvas` hook; this LiveView only owns slider state and presets.
  """
  use FugueWeb, :live_view

  alias FugueWeb.MenagerieLive.AnimatedCard
  alias FugueWeb.MenagerieLive.AnimatedCard.Slider

  @defaults %{
    "count" => 1500,
    "sep_radius" => 25.0,
    "align_radius" => 30.0,
    "cohesion_radius" => 35.0,
    "sep_force" => 0.06,
    "align_force" => 0.02,
    "cohesion_force" => 0.002,
    "max_speed" => 3.0,
    "min_speed" => 0.5,
    "trail_decay" => 0.97,
    "crowd_threshold" => 8.0
  }

  @sliders [
    Slider.new(
      key: "count",
      label: "Flock size",
      min: 50,
      max: 3000,
      step: 50,
      cast: &trunc/1,
      format: &Integer.to_string/1
    ),
    Slider.new(key: "sep_force", label: "Separation", min: 0.0, max: 0.3, step: 0.005),
    Slider.new(key: "align_force", label: "Alignment", min: 0.0, max: 0.2, step: 0.002),
    Slider.new(key: "cohesion_force", label: "Cohesion", min: 0.0, max: 0.02, step: 0.0002),
    Slider.new(key: "max_speed", label: "Max speed", min: 0.5, max: 8.0, step: 0.1),
    Slider.new(key: "trail_decay", label: "Trail persistence", min: 0.8, max: 0.999, step: 0.001)
  ]

  @presets %{
    "tight_flock" => %{
      "count" => 1200,
      "sep_radius" => 18.0,
      "align_radius" => 45.0,
      "cohesion_radius" => 60.0,
      "sep_force" => 0.08,
      "align_force" => 0.06,
      "cohesion_force" => 0.006,
      "max_speed" => 3.5,
      "min_speed" => 0.8,
      "trail_decay" => 0.96,
      "crowd_threshold" => 10.0
    },
    "schooling" => %{
      "count" => 2000,
      "sep_radius" => 12.0,
      "align_radius" => 60.0,
      "cohesion_radius" => 40.0,
      "sep_force" => 0.05,
      "align_force" => 0.1,
      "cohesion_force" => 0.003,
      "max_speed" => 4.0,
      "min_speed" => 1.0,
      "trail_decay" => 0.98,
      "crowd_threshold" => 12.0
    },
    "chaos" => %{
      "count" => 2500,
      "sep_radius" => 8.0,
      "align_radius" => 10.0,
      "cohesion_radius" => 15.0,
      "sep_force" => 0.15,
      "align_force" => 0.005,
      "cohesion_force" => 0.0005,
      "max_speed" => 6.0,
      "min_speed" => 2.0,
      "trail_decay" => 0.93,
      "crowd_threshold" => 4.0
    }
  }

  def mount(_params, _session, socket) do
    {:ok, assign(socket, params: @defaults, sliders: @sliders)}
  end

  def handle_event("update_params", form, socket) do
    AnimatedCard.handle_update_params(form, socket, @sliders, "boids:set_params")
  end

  def handle_event("preset", %{"name" => name}, socket) when is_map_key(@presets, name) do
    preset = Map.fetch!(@presets, name)

    {:noreply,
     socket
     |> assign(:params, preset)
     |> push_event("boids:reset", preset)}
  end

  def handle_event("reset", _params, socket) do
    AnimatedCard.handle_reset(socket, @defaults, "boids:reset")
  end

  def render(assigns) do
    ~H"""
    <div class="boids-menagerie p-4 max-w-6xl mx-auto">
      <nav class="mb-6 text-xs">
        <.link navigate={~p"/menagerie"} class="text-gray-500 hover:text-gray-300">
          ← Menagerie
        </.link>
      </nav>

      <div class="mb-4">
        <h1 class="text-2xl font-bold text-gray-100">Boids playground</h1>
        <p class="text-sm text-gray-400 mt-1 max-w-3xl leading-relaxed">
          Each bird follows three simple rules: steer away from crowded neighbors,
          turn toward the average heading of the flock, and drift toward the local
          center of mass. Small changes to any of the three produce wildly
          different group behavior: tight flocks, streaming schools, or ragged
          chaos.
        </p>
      </div>

      <div class="bg-base-200 rounded-lg overflow-hidden mb-4">
        <canvas
          id="menagerie-boids-canvas"
          phx-hook="BoidsCanvas"
          phx-update="ignore"
          class="block w-full"
          style="height: 480px;"
          data-count={@params["count"]}
          data-sep_radius={@params["sep_radius"]}
          data-align_radius={@params["align_radius"]}
          data-cohesion_radius={@params["cohesion_radius"]}
          data-sep_force={@params["sep_force"]}
          data-align_force={@params["align_force"]}
          data-cohesion_force={@params["cohesion_force"]}
          data-max_speed={@params["max_speed"]}
          data-min_speed={@params["min_speed"]}
          data-trail_decay={@params["trail_decay"]}
          data-crowd_threshold={@params["crowd_threshold"]}
        >
        </canvas>
      </div>

      <div class="flex flex-wrap gap-2 mb-4">
        <button
          type="button"
          phx-click="preset"
          phx-value-name="tight_flock"
          class="btn btn-xs btn-outline"
        >
          Tight flock
        </button>
        <button
          type="button"
          phx-click="preset"
          phx-value-name="schooling"
          class="btn btn-xs btn-outline"
        >
          Schooling
        </button>
        <button type="button" phx-click="preset" phx-value-name="chaos" class="btn btn-xs btn-outline">
          Chaos
        </button>
        <button type="button" phx-click="reset" class="btn btn-xs btn-ghost">
          Reset to defaults
        </button>
      </div>

      <AnimatedCard.slider_grid sliders={@sliders} params={@params} />
    </div>
    """
  end
end
