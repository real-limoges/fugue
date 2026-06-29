defmodule FugueWeb.MenagerieLive.QuantumStats do
  @moduledoc """
  Occupation histograms for Maxwell-Boltzmann, Bose-Einstein, and Fermi-Dirac
  statistics overlaid on one panel. A temperature slider drives all three
  toward the classical limit at high T and blows them apart at low T.
  """

  use FugueWeb, :live_view

  alias FugueWeb.MenagerieLive.AnimatedCard
  alias FugueWeb.MenagerieLive.AnimatedCard.Slider

  @defaults %{"log_temperature" => 0.0, "particles" => 18}

  @sliders [
    Slider.new(
      key: "log_temperature",
      label: "Temperature",
      min: -1.3,
      max: 1.3,
      step: 0.01,
      format: &__MODULE__.format_log_temperature/1
    ),
    Slider.new(
      key: "particles",
      label: "Particles",
      min: 3,
      max: 25,
      step: 1,
      cast: &trunc/1,
      format: &Integer.to_string/1
    )
  ]

  def mount(_params, _session, socket) do
    {:ok, assign(socket, params: @defaults, sliders: @sliders)}
  end

  def handle_event("update_params", form, socket) do
    AnimatedCard.handle_update_params(form, socket, @sliders, "quantum_stats:set_params")
  end

  def handle_event("reset", _params, socket) do
    AnimatedCard.handle_reset(socket, @defaults, "quantum_stats:set_params")
  end

  @doc false
  def format_log_temperature(log_t) do
    "kT = " <> :erlang.float_to_binary(:math.pow(10, log_t), decimals: 2)
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
          on top of each other. You'd think there was only one. Drag to the cold
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
          particles are indifferent, and once it's hot enough, the rule stops
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
          data-log_temperature={@params["log_temperature"]}
          data-particles={@params["particles"]}
        >
        </canvas>
      </div>

      <div class="flex flex-wrap gap-2 mb-4">
        <button type="button" phx-click="reset" class="btn btn-xs btn-ghost">
          Reset
        </button>
      </div>

      <AnimatedCard.slider_grid
        sliders={@sliders}
        params={@params}
        class="grid grid-cols-1 sm:grid-cols-2 gap-4"
      />
    </div>
    """
  end
end
