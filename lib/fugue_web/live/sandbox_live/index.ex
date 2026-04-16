defmodule FugueWeb.SandboxLive.Index do
  @moduledoc """
  Landing page for /sandbox — a thin index that points at the individual
  math-exploration experiments.
  """

  use FugueWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="sandbox-index p-4 max-w-6xl mx-auto">
      <header class="mb-12">
        <h1 class="text-3xl font-semibold text-gray-100 mb-3">Sandbox</h1>
        <p class="text-sm text-gray-400 leading-relaxed max-w-3xl">
          A small collection of math and simulation playgrounds. Each experiment
          is self-contained — drag sliders, break things, see what falls out.
        </p>
      </header>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <.link
          navigate={~p"/sandbox/fuzzy"}
          class="group block min-h-[220px] rounded-lg border border-white/5 bg-base-200 p-6 transition hover:border-white/20 hover:bg-base-300"
        >
          <p class="text-[10px] uppercase tracking-[0.2em] text-gray-500 mb-2">Fuzzy logic</p>
          <h2 class="text-xl font-semibold text-gray-100 mb-2">
            Triangular temperature bands
          </h2>
          <p class="text-sm text-gray-400 leading-relaxed">
            Reshape triangular membership bands over four years of Melbourne daily
            temperatures. Every day holds partial membership in five overlapping
            fuzzy sets at once — drag the sliders to see the gradient reshape.
          </p>
        </.link>

        <.link
          navigate={~p"/sandbox/mamdani"}
          class="group block min-h-[220px] rounded-lg border border-white/5 bg-base-200 p-6 transition hover:border-white/20 hover:bg-base-300"
        >
          <p class="text-[10px] uppercase tracking-[0.2em] text-gray-500 mb-2">Fuzzy logic</p>
          <h2 class="text-xl font-semibold text-gray-100 mb-2">
            Mamdani fan controller
          </h2>
          <p class="text-sm text-gray-400 leading-relaxed">
            An old-school rule of thumb wired up as a fuzzy controller: hot and
            humid means run hard, cold means off. Watch seven weighted rules fire
            in real time and turn two crisp inputs into a crisp fan speed.
          </p>
        </.link>

        <.link
          navigate={~p"/sandbox/boids"}
          class="group block min-h-[220px] rounded-lg border border-white/5 bg-base-200 p-6 transition hover:border-white/20 hover:bg-base-300"
        >
          <p class="text-[10px] uppercase tracking-[0.2em] text-gray-500 mb-2">Flocking</p>
          <h2 class="text-xl font-semibold text-gray-100 mb-2">Boids playground</h2>
          <p class="text-sm text-gray-400 leading-relaxed">
            Each bird follows three simple rules — separate from neighbors, align
            with them, cohere toward the flock. Drag the force sliders and watch
            tight flocks form, schools stream past each other, or the whole crowd
            dissolve into chaos.
          </p>
        </.link>

        <.link
          navigate={~p"/sandbox/quantum-walk"}
          class="group block min-h-[220px] rounded-lg border border-white/5 bg-base-200 p-6 transition hover:border-white/20 hover:bg-base-300"
        >
          <p class="text-[10px] uppercase tracking-[0.2em] text-gray-500 mb-2">Quantum</p>
          <h2 class="text-xl font-semibold text-gray-100 mb-2">
            Classical vs quantum walk
          </h2>
          <p class="text-sm text-gray-400 leading-relaxed">
            Two walkers start at the center. The classical one drifts into a bell;
            the quantum one races out into two horns at the edges. A decoherence
            slider blends one into the other — the dial that turns quantum back
            into classical.
          </p>
        </.link>

        <.link
          navigate={~p"/sandbox/quantum-stats"}
          class="group block min-h-[220px] rounded-lg border border-white/5 bg-base-200 p-6 transition hover:border-white/20 hover:bg-base-300"
        >
          <p class="text-[10px] uppercase tracking-[0.2em] text-gray-500 mb-2">Quantum</p>
          <h2 class="text-xl font-semibold text-gray-100 mb-2">Three ways to count</h2>
          <p class="text-sm text-gray-400 leading-relaxed">
            Three curves on one chart, one for each rule particles can follow
            about whether they're allowed to share a state. Drag the temperature:
            hot and they lie right on top of each other, cold and they peel into
            three dramatically different shapes.
          </p>
        </.link>

        <.link
          navigate={~p"/sandbox/sandpile"}
          class="group block min-h-[220px] rounded-lg border border-white/5 bg-base-200 p-6 transition hover:border-white/20 hover:bg-base-300"
        >
          <p class="text-[10px] uppercase tracking-[0.2em] text-gray-500 mb-2">Self-organized criticality</p>
          <h2 class="text-xl font-semibold text-gray-100 mb-2">Abelian sandpile</h2>
          <p class="text-sm text-gray-400 leading-relaxed">
            Drop grains onto a grid. When a cell hits four it topples, cascading
            to neighbors. The system tunes itself to a critical state — avalanche
            sizes follow a power law that nobody programmed in. Watch the
            log-log histogram converge to a straight line as grains accumulate.
          </p>
        </.link>
      </div>
    </div>
    """
  end
end
