defmodule FugueWeb.MenagerieLive.QuantumStats do
  @moduledoc """
  Occupation histograms for Maxwell-Boltzmann, Bose-Einstein, and Fermi-Dirac
  statistics overlaid on one panel. A temperature slider drives all three
  toward the classical limit at high T and blows them apart at low T.
  """

  use FugueWeb, :live_view

  @defaults %{log_temperature: 0.0, particles: 18}

  def mount(_params, _session, socket) do
    {:ok, assign(socket, params: @defaults)}
  end

  def handle_event("update_params", form, socket) do
    new_params = %{
      log_temperature:
        parse_float(form["log_temperature"], socket.assigns.params.log_temperature),
      particles: parse_int(form["particles"], socket.assigns.params.particles)
    }

    if new_params == socket.assigns.params do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> assign(:params, new_params)
       |> push_event("quantum_stats:set_params", new_params)}
    end
  end

  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> assign(:params, @defaults)
     |> push_event("quantum_stats:set_params", @defaults)}
  end

  defp parse_int(raw, fallback) when is_binary(raw) do
    case Integer.parse(raw) do
      {n, _} -> n
      :error -> fallback
    end
  end

  defp parse_int(_, fallback), do: fallback

  defp parse_float(raw, fallback) when is_binary(raw) do
    case Float.parse(raw) do
      {f, _} -> f
      :error -> fallback
    end
  end

  defp parse_float(_, fallback), do: fallback

  defp format_temperature(log_t) do
    t = :math.pow(10, log_t)
    :erlang.float_to_binary(t, decimals: 2)
  end

  def render(assigns) do
    ~H"""
    <div class="quantum-stats-menagerie p-4 max-w-6xl mx-auto">
      <nav class="mb-6 text-xs">
        <.link navigate={~p"/menagerie"} class="text-gray-500 hover:text-gray-300">
          ← Menagerie
        </.link>
      </nav>

      <div class="mb-4">
        <h1 class="text-2xl font-bold text-gray-100">Three ways to count</h1>
        <p class="text-sm text-gray-400 mt-1 max-w-3xl leading-relaxed">
          Drag the temperature slider. On the hot end, the three curves lie right
          on top of each other — you'd think there was only one. Drag to the cold
          end and they peel apart into three completely different shapes. One is
          a fat spike at the lowest level and nothing anywhere else. Another holds
          flat across many levels and then falls off a cliff. The third is a
          smooth decay from the left edge downward.
        </p>
        <p class="text-sm text-gray-400 mt-3 max-w-3xl leading-relaxed">
          These are three different rules about whether two particles can share a
          state: Bose-Einstein (the pile), Fermi-Dirac (the cliff), and
          Maxwell-Boltzmann (the smooth decay). Bosons can pile onto the same
          state without limit. Fermions can't share a state at all. Classical
          particles are indifferent — and once it's hot enough, the rule stops
          mattering.
        </p>
      </div>

      <div class="bg-base-200 rounded-lg overflow-hidden mb-4">
        <canvas
          id="menagerie-quantum-stats-canvas"
          phx-hook="QuantumStats"
          phx-update="ignore"
          class="block w-full"
          style="height: 420px;"
          data-log_temperature={@params.log_temperature}
          data-particles={@params.particles}
        >
        </canvas>
      </div>

      <div class="flex flex-wrap gap-2 mb-4">
        <button type="button" phx-click="reset" class="btn btn-xs btn-ghost">
          Reset
        </button>
      </div>

      <form phx-change="update_params" class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <label class="block bg-base-200 rounded-lg p-3">
          <div class="flex items-center justify-between mb-1">
            <span class="text-xs font-semibold text-gray-300">Temperature</span>
            <span class="text-xs font-mono text-gray-400">
              kT = {format_temperature(@params.log_temperature)}
            </span>
          </div>
          <input
            type="range"
            name="log_temperature"
            min="-1.3"
            max="1.3"
            step="0.01"
            value={@params.log_temperature}
            class="range range-xs range-primary"
          />
        </label>

        <label class="block bg-base-200 rounded-lg p-3">
          <div class="flex items-center justify-between mb-1">
            <span class="text-xs font-semibold text-gray-300">Particles</span>
            <span class="text-xs font-mono text-gray-400">{@params.particles}</span>
          </div>
          <input
            type="range"
            name="particles"
            min="3"
            max="25"
            step="1"
            value={@params.particles}
            class="range range-xs range-primary"
          />
        </label>
      </form>
    </div>
    """
  end
end
