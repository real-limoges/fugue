defmodule FugueWeb.CloudsLive do
  @moduledoc """
  `/clouds`: a still cumulus scene over a pixel-art barn. The LiveView is
  a thin shell that mounts the canvas; all rendering runs client-side via
  the `CloudsCanvas` hook in `assets/js/hooks/clouds_canvas.js`.

  The hook loads petri's `clouds.wasm` (2D Boussinesq moist convection)
  for its `qc` grid, paints Gaussian cloud lobes directly into that grid,
  and renders a single frame. It does not step the solver: a saturation
  step would evaporate freshly painted `qc`, because the matching `qv` was
  never raised to match. Drift and animation are unstarted work rather
  than something that regressed.

  The canvas is therefore inert, and deliberately so. A click handler used
  to fire `applyBubble` into the `qc` field, but with nothing stepping the
  solver the bubble was never integrated and the click did nothing; it and
  the `cursor: pointer` that advertised it were removed 2026-08-09.
  Interaction comes back only after the render loop does.

  Not Worley noise. The moduledoc and the on-page caption both said so
  until 2026-08-09, three implementations after it stopped being true.
  """
  use FugueWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="w-full">
      <div class="relative w-full">
        <.link
          navigate={~p"/"}
          class="absolute top-3 left-3 z-10 text-xs text-base-content/50 hover:text-base-content/90"
        >
          ←
        </.link>

        <canvas
          id="clouds-canvas"
          phx-hook="CloudsCanvas"
          phx-update="ignore"
          class="block w-full"
          style="aspect-ratio: 2 / 1; image-rendering: pixelated; image-rendering: crisp-edges;"
        >
        </canvas>
      </div>

      <.figure_source
        note="Cloud water painted straight into the grid of a moist-convection solver, then lit as if it were volume: sun-direction surface normals, a short shadow march, two octaves of noise for the cauliflower. The solver is initialized and then never stepped, so this is a still life rather than a simulation."
        repo="petri"
      />

      <img
        src={~p"/images/clouds_preseed.png"}
        alt="pre-rendered pixel-art clouds reference"
        class="block w-full mt-4"
        style="aspect-ratio: 2 / 1; image-rendering: pixelated; image-rendering: crisp-edges;"
      />

      <.source_link repos={["petri", {"fugue", "lib/fugue_web/live/clouds_live.ex"}]} />
    </div>
    """
  end
end
