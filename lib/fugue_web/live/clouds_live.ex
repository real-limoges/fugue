defmodule FugueWeb.CloudsLive do
  @moduledoc """
  `/clouds` — pixel-art Worley-noise canvas. The LiveView is a thin
  shell that mounts the canvas; all rendering runs client-side via the
  `CloudsCanvas` hook in `assets/js/hooks/clouds_canvas.js`.
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
          style="aspect-ratio: 2 / 1; image-rendering: pixelated; image-rendering: crisp-edges; cursor: pointer;"
        >
        </canvas>
      </div>

      <img
        src={~p"/images/clouds_preseed.png"}
        alt="pre-rendered pixel-art clouds reference"
        class="block w-full mt-4"
        style="aspect-ratio: 2 / 1; image-rendering: pixelated; image-rendering: crisp-edges;"
      />
    </div>
    """
  end
end
