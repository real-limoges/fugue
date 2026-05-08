defmodule FugueWeb.MenagerieLive.QuantumWalk do
  @moduledoc """
  Classical vs quantum random walk, side by side, with a decoherence slider
  that morphs the quantum walk into the classical one.
  """

  use FugueWeb, :live_view

  alias FugueWeb.MenagerieLive.AnimatedCard
  alias FugueWeb.MenagerieLive.AnimatedCard.Slider

  @defaults %{"steps" => 80, "decoherence" => 0.0}

  @sliders [
    Slider.new(
      key: "decoherence",
      label: "Decoherence",
      min: 0.0,
      max: 1.0,
      step: 0.01,
      format: &__MODULE__.format_decoherence/1
    ),
    Slider.new(
      key: "steps",
      label: "Steps",
      min: 10,
      max: 160,
      step: 2,
      cast: &trunc/1,
      format: &Integer.to_string/1
    )
  ]

  def mount(_params, _session, socket) do
    {:ok, assign(socket, params: @defaults, sliders: @sliders)}
  end

  def handle_event("update_params", form, socket) do
    AnimatedCard.handle_update_params(form, socket, @sliders, "quantum_walk:set_params")
  end

  def handle_event("reset", _params, socket) do
    AnimatedCard.handle_reset(socket, @defaults, "quantum_walk:set_params")
  end

  @doc false
  def format_decoherence(d), do: :erlang.float_to_binary(d, decimals: 2)

  def render(assigns) do
    ~H"""
    <div class="quantum-walk-menagerie p-4 max-w-6xl mx-auto">
      <nav class="mb-6 text-xs">
        <.link navigate={~p"/menagerie"} class="text-gray-500 hover:text-gray-300">
          ← Menagerie
        </.link>
      </nav>

      <div class="mb-4">
        <h1 class="text-2xl font-bold text-gray-100">Classical vs quantum walk</h1>
        <p class="text-sm text-gray-400 mt-1 max-w-3xl leading-relaxed">
          Both walkers start at the center and take {@params["steps"]} steps. The gray
          one takes a classical random walk -- coin flip, step, coin flip, step --
          and settles into the familiar bell curve. The cyan one takes a quantum
          walk, and does something strange: it refuses to settle in the middle and
          spreads to the edges instead, piling up in two sharp horns at the outer
          limits of where it could possibly be.
        </p>
        <p class="text-sm text-gray-400 mt-3 max-w-3xl leading-relaxed">
          Drag decoherence. At zero, the quantum walker stays weird. Turn it up
          and the weirdness drains out step by step until you're back to the bell.
          The slider is the dial that turns quantum into classical.
        </p>
      </div>

      <div class="bg-base-200 rounded-lg overflow-hidden mb-4">
        <canvas
          id="menagerie-quantum-walk-canvas"
          phx-hook="QuantumWalk"
          phx-update="ignore"
          class="block w-full"
          style="height: 420px;"
          data-steps={@params["steps"]}
          data-decoherence={@params["decoherence"]}
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
