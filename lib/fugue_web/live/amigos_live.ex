defmodule FugueWeb.AmigosLive do
  @moduledoc """
  `/amigos`: a recap of Arrested Development S2E3, "¡Amigos!", that gets
  denser as the reader scrolls, until it can't be read.

  The page is a pinned stage (`FugueWeb.AmigosLive.Stage`) over a tall
  scroll track. The `AmigosScroll` hook reports each beat the reader
  reaches, in either direction, so scrolling back up peels layers off
  again for a reader who went too fast. After the last layer the track
  ends and the ending appears: a counter that says how many layers there
  were, one short, because Ann's layer is on the page but never counted
  (`Fugue.Amigos.counted_count/0`).

  Readers who prefer reduced motion get the finished page, still, with a
  button to watch it build.
  """
  use FugueWeb, :live_view

  alias Fugue.Amigos
  alias FugueWeb.AmigosLive.Stage
  alias Phoenix.LiveView.JS

  # The ending is the beat after the last layer.
  @last_beat Amigos.last_beat() + 1

  # How far the reader scrolls per beat, in percent of the viewport height.
  # The whole track is one of these per layer beat, plus one screen for the
  # pinned stage.
  @beat_svh 100

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "¡Amigos!")
     |> assign(
       :meta_description,
       "A recap of one Arrested Development episode that keeps adding layers until it can't be read."
     )
     |> assign(:last_beat, @last_beat)
     |> assign(:beat, 1)
     |> assign(:mode, :scroll)}
  end

  def handle_event("beat", %{"beat" => beat}, socket) when is_integer(beat) do
    reached = beat |> max(1) |> min(@last_beat)
    {:noreply, assign(socket, :beat, reached)}
  end

  def handle_event("reduced_motion", _params, socket) do
    {:noreply, assign(socket, beat: @last_beat, mode: :static)}
  end

  def handle_event("watch_build", _params, socket) do
    {:noreply, assign(socket, beat: 1, mode: :scroll)}
  end

  def render(assigns) do
    ~H"""
    <article
      id="amigos"
      phx-hook="AmigosScroll"
      data-beat={@beat}
      data-mode={@mode}
      class="amigos-page relative -my-12 py-12"
    >
      <header class="mb-6 max-w-2xl">
        <h1 class="amigos-display text-5xl sm:text-6xl leading-none">¡Amigos!</h1>
        <p class="text-base-content/80 mt-2">
          Arrested Development, season 2, episode 3. Keep scrolling.
        </p>
      </header>

      <section
        :if={@mode == :scroll}
        id="amigos-track"
        class="relative"
        style={"height: #{track_svh()}svh"}
      >
        <span
          :for={beat <- 1..@last_beat}
          data-beat-marker={beat}
          aria-hidden="true"
          class="absolute left-0 h-px w-px"
          style={"top: #{marker_svh(beat)}svh"}
        ></span>
        <Stage.stage beat={@beat} pinned={true} />
      </section>

      <Stage.stage :if={@mode == :static} beat={@beat} pinned={false} />

      <.ending :if={@beat >= @last_beat} counted={Amigos.counted_count()} mode={@mode} />

      <.source_link repos={[{"fugue", "lib/fugue_web/live/amigos_live"}]} />
    </article>
    """
  end

  defp marker_svh(beat), do: (beat - 1) * @beat_svh
  defp track_svh, do: marker_svh(@last_beat) + 100

  attr :counted, :integer, required: true
  attr :mode, :atom, required: true

  defp ending(assigns) do
    ~H"""
    <section id="amigos-ending" class="mx-auto max-w-xl pt-[30svh] pb-[20svh] text-center">
      <p id="amigos-counter" class="text-lg text-base-content/90">
        Nobody could have followed every layer. And there were only {@counted} of them.<sup class="text-secondary pl-0.5">*</sup>
      </p>
      <p id="amigos-late-footnote" class="mt-16 text-xs text-base-content/70">
        <sup class="text-secondary pr-0.5">*</sup>That count is wrong.
      </p>
      <button
        :if={@mode == :static}
        id="amigos-watch-build"
        type="button"
        phx-click={JS.dispatch("amigos:top", to: "#amigos") |> JS.push("watch_build")}
        class="btn btn-sm btn-ghost mt-12 font-mono"
      >
        watch it build
      </button>
    </section>
    """
  end
end
