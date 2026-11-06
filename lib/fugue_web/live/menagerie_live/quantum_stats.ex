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

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, params: @defaults, sliders: @sliders)}
  end

  @impl true
  def handle_event("update_params", form, socket) do
    AnimatedCard.handle_update_params(form, socket, @sliders, "quantum_stats:set_params")
  end

  def handle_event("reset", _params, socket) do
    AnimatedCard.handle_reset(socket, @defaults, "quantum_stats:set_params")
  end

  @doc false
  @spec format_log_temperature(number()) :: String.t()
  def format_log_temperature(log_t) do
    "kT = " <> :erlang.float_to_binary(:math.pow(10, log_t), decimals: 2)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="quantum-stats-menagerie p-4 max-w-6xl mx-auto">
      <nav class="mb-6 text-xs">
        <.link navigate={~p"/menagerie"} class="text-base-content/45 hover:text-base-content/75">
          ← Menagerie
        </.link>
      </nav>

      <div class="mb-4">
        <h1 class="text-2xl font-bold text-base-content">Three ways to count</h1>
        <p class="text-sm text-base-content/60 mt-1 max-w-3xl leading-relaxed">
          Drag the temperature to the hot end and the three curves sit right on
          top of each other, close enough that you'd think there was only one.
          Drag it cold and they come apart into shapes that look like they belong
          to different problems: a huge spike on the lowest level with nothing
          anywhere else, a flat shelf that drops off a cliff, and a smooth slide
          down from the left.
        </p>
        <p class="text-sm text-base-content/60 mt-3 max-w-3xl leading-relaxed">
          The only thing that differs is a rule about sharing. Bosons
          (Bose-Einstein, the spike) are happy to pile into the same state, as
          many as you like. Fermions (Fermi-Dirac, the cliff) can't share at
          all, so they fill the levels one at a time from the bottom, like seats
          in a theater. Classical particles (Maxwell-Boltzmann, the smooth slide)
          don't care either way. When it's hot there's so much room that nobody
          is competing for a state and the rule stops mattering; the cold end is
          where it shows.
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
        ></canvas>
      </div>

      <.figure_source
        note="Bose-Einstein, Fermi-Dirac and Maxwell-Boltzmann occupancy over the same ladder of states. The only difference in the code is whether particles are allowed to share a level."
        repo={{"fugue", "assets/js/hooks/quantum_stats.js"}}
      />

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

      <.source_link repos={[{"fugue", "lib/fugue_web/live/menagerie_live/quantum_stats.ex"}]} />
    </div>
    """
  end
end
