defmodule FugueWeb.SandboxLive.Index do
  @moduledoc """
  Landing page for /sandbox — a thin index that points at the individual
  math-exploration experiments, with a pair of small generative doodles in the
  empty cells.
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
            Triangular bands & a Mamdani fan
          </h2>
          <p class="text-sm text-gray-400 leading-relaxed">
            Reshape membership functions over four years of Melbourne daily
            temperatures, then watch a Mamdani controller fuzzify, fire rules,
            and defuzzify in real time through Hazy.
          </p>
        </.link>

        <figure class="relative min-h-[220px] overflow-hidden rounded-lg border border-white/5 bg-base-200">
          <canvas
            id="sandbox-index-lissajous"
            phx-hook="LissajousDoodle"
            phx-update="ignore"
            class="block h-full w-full"
            style="min-height: 220px;"
          >
          </canvas>
          <figcaption class="absolute bottom-3 left-4 text-[10px] uppercase tracking-[0.2em] text-gray-500">
            Lissajous · x = sin(at+δ), y = sin(bt)
          </figcaption>
        </figure>

        <figure class="relative min-h-[220px] overflow-hidden rounded-lg border border-white/5 bg-base-200">
          <canvas
            id="sandbox-index-rule30"
            phx-hook="Rule30Doodle"
            phx-update="ignore"
            class="block h-full w-full"
            style="min-height: 220px;"
          >
          </canvas>
          <figcaption class="absolute bottom-3 left-4 text-[10px] uppercase tracking-[0.2em] text-gray-500">
            Rule 30 · 1D cellular automaton
          </figcaption>
        </figure>

        <.link
          navigate={~p"/sandbox/boids"}
          class="group block min-h-[220px] rounded-lg border border-white/5 bg-base-200 p-6 transition hover:border-white/20 hover:bg-base-300"
        >
          <p class="text-[10px] uppercase tracking-[0.2em] text-gray-500 mb-2">Flocking</p>
          <h2 class="text-xl font-semibold text-gray-100 mb-2">Boids playground</h2>
          <p class="text-sm text-gray-400 leading-relaxed">
            A WebAssembly boids sim with live sliders for separation, alignment,
            cohesion, and trail persistence. Tune the forces; watch flocks form,
            schools stream, or dissolve into chaos.
          </p>
        </.link>
      </div>
    </div>
    """
  end
end
