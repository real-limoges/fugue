defmodule FugueWeb.SandboxLive.Boids do
  use FugueWeb, :live_view

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
    {"count", "Flock size", 50, 3000, 50, &trunc/1},
    {"sep_force", "Separation", 0.0, 0.3, 0.005, &Function.identity/1},
    {"align_force", "Alignment", 0.0, 0.2, 0.002, &Function.identity/1},
    {"cohesion_force", "Cohesion", 0.0, 0.02, 0.0002, &Function.identity/1},
    {"max_speed", "Max speed", 0.5, 8.0, 0.1, &Function.identity/1},
    {"trail_decay", "Trail persistence", 0.8, 0.999, 0.001, &Function.identity/1}
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

  def handle_event("update_params", form_params, socket) do
    new_params = parse_params(form_params, socket.assigns.params)

    if new_params == socket.assigns.params do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> assign(:params, new_params)
       |> push_event("boids:set_params", new_params)}
    end
  end

  def handle_event("preset", %{"name" => name}, socket) when is_map_key(@presets, name) do
    preset = Map.fetch!(@presets, name)

    {:noreply,
     socket
     |> assign(:params, preset)
     |> push_event("boids:reset", preset)}
  end

  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> assign(:params, @defaults)
     |> push_event("boids:reset", @defaults)}
  end

  defp parse_params(form, current) do
    Enum.reduce(@sliders, current, fn {key, _label, _min, _max, _step, cast}, acc ->
      case Map.fetch(form, key) do
        {:ok, raw} ->
          Map.put(acc, key, parse_number(raw, current[key]) |> cast.())

        :error ->
          acc
      end
    end)
  end

  defp parse_number(raw, fallback) when is_binary(raw) do
    case Float.parse(raw) do
      {val, _} -> val
      :error -> fallback
    end
  end

  defp parse_number(_, fallback), do: fallback

  defp format_value("count", v), do: trunc(v) |> Integer.to_string()
  defp format_value(_, v) when is_float(v), do: :erlang.float_to_binary(v, decimals: 4)
  defp format_value(_, v), do: to_string(v)

  def render(assigns) do
    ~H"""
    <div class="boids-sandbox p-4 max-w-6xl mx-auto">
      <nav class="mb-6 text-xs">
        <.link navigate={~p"/sandbox"} class="text-gray-500 hover:text-gray-300">
          ← Sandbox
        </.link>
      </nav>

      <div class="mb-4">
        <h1 class="text-2xl font-bold text-gray-100">Boids playground</h1>
        <p class="text-sm text-gray-400 mt-1 max-w-3xl leading-relaxed">
          Each bird follows three simple rules: steer away from crowded neighbors,
          turn toward the average heading of the flock, and drift toward the local
          center of mass. Small changes to any of the three produce wildly
          different group behavior — tight flocks, streaming schools, or ragged
          chaos.
        </p>
      </div>

      <div class="bg-base-200 rounded-lg overflow-hidden mb-4">
        <canvas
          id="sandbox-boids-canvas"
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

      <form phx-change="update_params" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <%= for {key, label, min, max, step, _cast} <- @sliders do %>
          <label class="block bg-base-200 rounded-lg p-3">
            <div class="flex items-center justify-between mb-1">
              <span class="text-xs font-semibold text-gray-300">{label}</span>
              <span class="text-xs font-mono text-gray-400">{format_value(key, @params[key])}</span>
            </div>
            <input
              type="range"
              name={key}
              min={min}
              max={max}
              step={step}
              value={@params[key]}
              class="range range-xs range-primary"
            />
          </label>
        <% end %>
      </form>
    </div>
    """
  end
end
