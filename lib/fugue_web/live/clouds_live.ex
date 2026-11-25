defmodule FugueWeb.CloudsLive do
  @moduledoc """
  `/clouds`: a still cumulus scene over a pixel-art barn, served as a
  static image (`priv/static/images/clouds.png`).

  The picture came from petri's `clouds.wasm` (2D Boussinesq moist
  convection): a hook painted Gaussian cloud lobes into the solver's `qc`
  grid and rendered one frame. It never stepped the solver, because a
  saturation step would evaporate the painted `qc` (the matching `qv` was
  never raised). With no randomness, no theme and a fixed 800x400 canvas,
  every visitor got the same frame, so on 2026-11-25 the frame was captured
  at native size and the hook deleted. Drift and animation are unstarted
  work; if they start, the hook comes back from git history.

  Not Worley noise. The moduledoc and the on-page caption both said so
  until 2026-08-09, three implementations after it stopped being true.
  """
  use FugueWeb, :live_view

  @impl true
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

        <img
          src={~p"/images/clouds.png"}
          alt="Three pixel-art cumulus clouds over a red barn and green fields"
          width="800"
          height="400"
          class="block w-full h-auto"
          style="image-rendering: pixelated; image-rendering: crisp-edges;"
        />
      </div>

      <.figure_source
        note="Cloud water painted straight into the grid of a moist-convection solver, then lit as if it were volume: sun-direction surface normals, a short shadow march, two octaves of noise for the cauliflower. The solver is initialized and then never stepped, so this is a still life rather than a simulation, and the page shows one captured frame of it."
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
