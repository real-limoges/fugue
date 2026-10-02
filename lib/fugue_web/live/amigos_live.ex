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
    <section
      id="amigos-ending"
      class="amigos-display mx-auto max-w-xl pt-[30svh] pb-[20svh] text-center"
    >
      <p id="amigos-counter" class="text-2xl text-base-content/90">
        Nobody could have followed every layer. And there were only {@counted} of them.<sup class="text-secondary pl-0.5">*</sup>
      </p>
      <p id="amigos-late-footnote" class="mt-16 text-sm text-base-content/70">
        <sup class="text-secondary pr-0.5">*</sup>That count is wrong.
      </p>
      <%!-- The credits' circle, drawn around Ann. There is no photo, only the
           default avatar: she is as easy to miss here as she was in the count. --%>
      <div id="amigos-ann" class="relative mx-auto mt-16 h-52 w-80">
        <span class="sr-only">Ann.</span>
        <svg
          viewBox="0 0 40 40"
          aria-hidden="true"
          class="absolute top-[30px] left-[92px] size-40 rounded-full"
        >
          <rect width="40" height="40" fill="oklch(84% 0 0)" />
          <circle cx="20" cy="16" r="7" fill="oklch(96% 0 0)" />
          <path
            d="M 6 40 C 6 30, 12 26, 20 26 C 28 26, 34 30, 34 40 Z"
            fill="oklch(96% 0 0)"
          />
        </svg>
        <%!-- The loop from the show's logo (Wikimedia Commons,
             File:Arrested_Development.svg): open, tapered, coming back round
             across the top inside its own start, the way you circle something
             while on the phone. Ann is large enough that the inner arc crosses
             the top of her head. A filled shape, so it fades in rather than drawing. --%>
        <svg
          viewBox="0 0 348.4 175.9"
          preserveAspectRatio="none"
          aria-hidden="true"
          class="pointer-events-none absolute inset-0 h-full w-full text-base-content motion-safe:animate-amigos-in"
        >
          <path
            fill="currentColor"
            d="M120.9062 175.29618c-39.47817-1.41938-74.304666-7.06428-92-14.91196-9.865971-4.37544-12.515679-5.97295-17.572039-10.59417C3.062879 142.23056.618065 137.40037.113739 127.62199c-.33147-6.42687.0134-9.31286 1.675889-14.02427C9.133611 92.78522 32.558211 72.459667 65.9062 57.96369c36.03304-15.663138 69.04504-22.356217 97.75941-19.820413 19.81361 1.749766 35.14899 6.396692 37.39779 11.332282 1.64679 3.614304.37039 4.263015-2.35592 1.19736-1.59662-1.795358-4.93716-3.339201-10.90954-5.041891-35.93262-10.244171-84.04042-2.833419-129.193568 19.901584C23.657269 83.128784 3.007087 105.97111 2.927292 127.12016c-.02759 7.3124 4.428598 16.51854 10.304424 21.28815 11.836505 9.60811 33.74223 16.44399 66.174484 20.65036 11.00174 1.42689 65.29221 3.92183 86 3.95216 27.66971.0405 64.93197-3.36821 87.60612-8.01419 39.58784-8.11162 68.04011-23.90786 82.61567-45.86687 11.90789-17.93999 12.21873-39.391334.79118-54.59989-18.78969-25.006598-73.89167-49.961156-128.19326-58.056104-38.10819-5.680935-88.90638-1.933855-130.31971 9.61291-4.125 1.150123-9.075 2.452691-11 2.894596-6.748173 1.54912-13.518411 3.322741-15.5 4.060585-1.1.409585-4.25 1.182689-7 1.71801-2.75.53532-5.9 1.307515-7 1.715988-1.598048.593419-1.698536.525957-.5-.335669 1.280142-.920293 14.063101-5.282215 31-10.578115 5.26797-1.647211 19.75659-5.331021 25.5-6.483516 2.2-.44146 8.5-1.720849 14-2.843087C169.40268-6.4144831 230.01514.214023 286.64387 25.836697c22.59488 10.223454 34.05572 17.589222 46.56838 29.929033 11.76821 11.605644 16.80991 25.344714 14.71664 40.10417-1.92199 13.55177-7.12381 23.78248-18.0301 35.46084-14.69869 15.73921-36.78046 26.94702-67.99259 34.51029-31.8901 7.72756-59.25075 10.3779-103 9.97729-17.325-.15864-34.425-.3936-38-.52214z"
          />
        </svg>
      </div>
      <button
        :if={@mode == :static}
        id="amigos-watch-build"
        type="button"
        phx-click={JS.dispatch("amigos:top", to: "#amigos") |> JS.push("watch_build")}
        class="btn btn-sm btn-ghost mt-16 font-mono"
      >
        watch it build
      </button>
    </section>
    """
  end
end
