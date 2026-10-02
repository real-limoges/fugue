defmodule FugueWeb.AmigosLive.Stage do
  @moduledoc """
  The pinned "page" that `/amigos` annotates, one zone per kind of layer.

  Everything here renders from two values: the beat the reader has reached
  and the layers in `Fugue.Amigos`. Each zone appears on the first beat of
  the layer it holds, so the beat numbers live in the data, not here. The
  crowded zones add one layer per beat, so the pile-up builds instead of
  landing all at once. Layer text comes from the data; the only copy
  written here is the stage's own labels (the spine sentence, corner
  captions, the column headings), so the research table stays the single
  source of what the gags are.

  Zones sit at fixed positions on a screen-high stage, so the page gets
  denser in place instead of getting longer. Overlap near the end is
  deliberate.
  """
  use Phoenix.Component

  import FugueWeb.CoreComponents, only: [icon: 1]

  alias Fugue.Amigos
  alias FugueWeb.AmigosLive.Clutter

  # The last six layers, one per beat, each pinned onto an annotation that
  # is already on the stage. Position and tilt are part of the overload.
  @overload [
    {:friends_titles, :gobs_friend, "top-[7%] left-[30%] -rotate-2"},
    {:george_sr, :blueprint, "top-[22%] left-[52%] -rotate-1"},
    {:circumvent, :surveillance, "top-[34%] right-[21%] -rotate-3"},
    {:tracy, :crossed_conversations, "top-[47%] left-[20%] rotate-3"},
    {:posters_banners, :radio, "top-[63%] left-[36%] rotate-1"},
    {:gene, :surveillance, "top-[77%] right-[9%] rotate-2"}
  ]

  attr :beat, :integer, required: true
  attr :pinned, :boolean, required: true

  def stage(assigns) do
    ~H"""
    <div
      id="amigos-stage"
      class={[
        "relative w-full overflow-hidden bg-base-100 text-base-content",
        if(@pinned,
          do: "sticky top-16 h-[calc(100svh-4rem)]",
          else: "h-[calc(100svh-4rem)] min-h-[46rem]"
        )
      ]}
    >
      <.margin beat={@beat} direction={:callback} />
      <.margin beat={@beat} direction={:foreshadowing} />

      <.spine beat={@beat} />
      <.footnotes :if={on?(:ice_off_duty, @beat)} beat={@beat} />
      <.callback_notes :if={on?(:silent_film, @beat)} beat={@beat} />
      <.columns :if={on?(:crossed_conversations, @beat)} />
      <.corners :if={on?(:offices_props, @beat)} />
      <.blue_line :if={on?(:blueprint, @beat)} />
      <.forward_notes :if={on?(:buster_mexico, @beat)} beat={@beat} />
      <.insert :if={on?(:spanish, @beat)} />
      <Clutter.clutter beat={@beat} />
      <.overload :if={on?(:friends_titles, @beat)} beat={@beat} />
    </div>
    """
  end

  # -- the spine --------------------------------------------------------------

  attr :beat, :integer, required: true

  defp spine(assigns) do
    ~H"""
    <p
      id="amigos-spine"
      class="absolute top-[5%] left-1/2 -translate-x-1/2 w-[min(40rem,56%)] text-center text-lg sm:text-2xl leading-snug font-medium"
    >
      Michael tells Gob he has no friends.<sup
        :if={on?(:ice_off_duty, @beat)}
        class="text-xs text-secondary pl-0.5 motion-safe:animate-amigos-in"
      >1</sup>
    </p>
    """
  end

  # -- footnotes, then footnotes on footnotes ---------------------------------

  attr :beat, :integer, required: true

  defp footnotes(assigns) do
    assigns =
      assign(assigns,
        gobs: Amigos.layer!(:gobs_friend),
        ice: Amigos.layer!(:ice_off_duty),
        surveillance: Amigos.layer!(:surveillance),
        radio: Amigos.layer!(:radio),
        hielo: Amigos.layer!(:ice_off_duty) |> Amigos.connections(:callback) |> hd(),
        nested: on?(:surveillance, assigns.beat)
      )

    ~H"""
    <ol
      id="amigos-footnotes"
      class="absolute top-[13%] left-1/2 -translate-x-1/2 w-[min(40rem,56%)] space-y-1 text-[11px] sm:text-xs leading-snug text-base-content/80"
    >
      <li id="layer-gobs_friend" class="motion-safe:animate-amigos-in">
        <sup class="text-secondary pr-1">1</sup>{@gobs.summary}<sup class="text-secondary pl-0.5">2</sup>
      </li>
      <li id="layer-ice_off_duty" class="motion-safe:animate-amigos-in">
        <sup class="text-secondary pr-1">2</sup>{@ice.summary}
        <span class="text-base-content/55">
          Also: {@hielo.target}, where {@hielo.note}.
        </span>
        <sup :if={@nested} class="text-secondary pl-0.5">3</sup>
      </li>
      <li
        :if={@nested}
        id="layer-surveillance"
        class="ml-4 motion-safe:animate-amigos-in"
      >
        <sup class="text-secondary pr-1">3</sup>{@surveillance.summary}<sup class="text-secondary pl-0.5">4</sup>
      </li>
      <li :if={@nested} id="layer-radio" class="ml-8 motion-safe:animate-amigos-in">
        <sup class="text-secondary pr-1">4</sup>{@radio.summary}<sup class="text-secondary pl-0.5">5</sup>
      </li>
      <li :if={@nested} class="ml-12 text-base-content/55 motion-safe:animate-amigos-in">
        <sup class="text-secondary pr-1">5</sup>Michael, meanwhile, is only looking for his father.
      </li>
    </ol>
    """
  end

  # -- arrows in the margins --------------------------------------------------

  attr :beat, :integer, required: true
  attr :direction, :atom, required: true

  defp margin(assigns) do
    from = Amigos.arrows_from(assigns.direction)

    arrows =
      if assigns.beat >= from do
        for layer <- Amigos.revealed_by(assigns.beat),
            connection <- Amigos.connections(layer, assigns.direction),
            do: {layer, connection}
      else
        []
      end

    assigns = assign(assigns, arrows: arrows)

    ~H"""
    <ul
      id={"amigos-#{@direction}"}
      aria-label={
        if @direction == :callback,
          do: "Callbacks to earlier episodes",
          else: "Foreshadowing of later episodes"
      }
      class={[
        "absolute top-[5%] bottom-[5%] w-[23%] max-w-56 space-y-1.5 overflow-hidden",
        "text-[9px] sm:text-[10px] leading-tight",
        if(@direction == :callback, do: "left-0", else: "right-0")
      ]}
    >
      <.arrow :for={{layer, connection} <- @arrows} layer={layer} connection={connection} />
    </ul>
    """
  end

  attr :layer, :map, required: true
  attr :connection, :map, required: true

  # Callbacks and foreshadowing differ by arrow direction, line style and
  # label, never by color alone: the site's owner is colorblind.
  defp arrow(assigns) do
    ~H"""
    <li class={[
      "flex gap-1 pl-1.5 border-l-2 motion-safe:animate-amigos-in",
      if(@connection.direction == :callback,
        do: "border-solid border-secondary",
        else: "border-dashed border-accent"
      )
    ]}>
      <.icon
        name={if @connection.direction == :callback, do: "hero-arrow-up", else: "hero-arrow-down"}
        class="size-3 shrink-0"
      />
      <span>
        <span class="sr-only">
          {if @connection.direction == :callback, do: "Calls back to", else: "Foreshadows"}
        </span>
        <span class="font-semibold">{@connection.target}</span>
        <span class="text-base-content/60">{@layer.name}: {@connection.note}</span>
      </span>
    </li>
    """
  end

  # -- the layers whose arrows point back, one per beat -----------------------

  attr :beat, :integer, required: true

  defp callback_notes(assigns) do
    assigns =
      assign(assigns,
        layers:
          on_page(
            ~w(silent_film tobias_blue real_world_refs borrowed_misunderstandings)a,
            assigns.beat
          )
      )

    ~H"""
    <div class="absolute top-[50%] left-1/2 -translate-x-1/2 w-[min(40rem,56%)] grid grid-cols-2 gap-x-3 gap-y-1.5">
      <.note :for={layer <- @layers} layer={layer} clamp />
    </div>
    """
  end

  # -- two people talking past each other -------------------------------------

  defp columns(assigns) do
    assigns =
      assign(assigns,
        hog: Amigos.layer!(:hog),
        crossed: Amigos.layer!(:crossed_conversations),
        ann: Amigos.layer!(:ann)
      )

    ~H"""
    <div
      id="layer-crossed_conversations"
      class="absolute top-[63%] left-1/2 -translate-x-1/2 w-[min(40rem,56%)] text-[11px] sm:text-xs leading-snug motion-safe:animate-amigos-in"
    >
      <div class="grid grid-cols-2 gap-x-4">
        <p class="font-semibold text-base-content/70">Maeby, about her mother and Ice</p>
        <p class="font-semibold text-base-content/70">Michael, about George Michael and Ann</p>
        <p>It's a shared problem.</p>
        <p>It's a shared problem.</p>
        <p class="col-span-2 py-1 text-center text-base-content/60" id="layer-hog">
          {@hog.summary}
        </p>
        <p>"Not a race thing."</p>
        <p>"Yeah, we won."</p>
      </div>
      <p class="mt-1.5 text-base-content/55">{@crossed.summary}</p>
      <p id="layer-ann" class="mt-1.5 text-[10px] text-base-content/45">
        <span class="font-semibold">{@ann.name}.</span> {@ann.summary}
      </p>
    </div>
    """
  end

  # -- things in the corners --------------------------------------------------

  defp corners(assigns) do
    assigns = assign(assigns, props: Amigos.layer!(:offices_props))

    ~H"""
    <div id="layer-offices_props" class="contents">
      <p class="absolute top-[1.5%] left-[25%] text-[10px] -rotate-2 border border-base-content/20 px-1.5 py-0.5 motion-safe:animate-amigos-in">
        a Cornballer box, and its mix
      </p>
      <p class="absolute top-[1.5%] right-[25%] text-[10px] rotate-1 border border-base-content/20 px-1.5 py-0.5 motion-safe:animate-amigos-in">
        Mr. Bananagrabber Christmas cards
      </p>
      <p class="absolute bottom-[1.5%] left-[25%] text-[10px] rotate-2 border border-base-content/20 px-1.5 py-0.5 motion-safe:animate-amigos-in">
        a Cloudmir vodka ad, on a wall in Mexico
      </p>
      <p class="absolute bottom-[1.5%] right-[25%] text-[10px] -rotate-6 text-base-content/60 motion-safe:animate-amigos-in">
        (someone in the background falls over)
      </p>
      <p class="sr-only">{@props.summary}</p>
    </div>
    """
  end

  # -- the blue line ----------------------------------------------------------

  defp blue_line(assigns) do
    assigns = assign(assigns, blueprint: Amigos.layer!(:blueprint))

    ~H"""
    <div id="layer-blueprint" class="contents">
      <div
        aria-hidden="true"
        class="absolute top-[4%] bottom-[4%] left-[63%] w-[3px] rounded-full bg-(--amigos-blue) origin-top motion-safe:animate-amigos-draw"
      >
      </div>
      <p class="absolute top-[11%] left-[64%] text-[10px] font-medium motion-safe:animate-amigos-in">
        <span
          aria-hidden="true"
          class="inline-block size-2 rounded-full bg-(--amigos-blue) ring-1 ring-base-content/70 -ml-[13px] mr-1.5"
        ></span>
        Starla's blueprint paper
      </p>
      <p class="absolute top-[33%] left-[64%] text-[10px] font-medium motion-safe:animate-amigos-in">
        <span
          aria-hidden="true"
          class="inline-block size-2 rounded-full bg-(--amigos-blue) ring-1 ring-base-content/70 -ml-[13px] mr-1.5"
        ></span>
        the picture of George Sr.
      </p>
      <p class="absolute top-[55%] left-[64%] text-[10px] font-medium motion-safe:animate-amigos-in">
        <span
          aria-hidden="true"
          class="inline-block size-2 rounded-full bg-(--amigos-blue) ring-1 ring-base-content/70 -ml-[13px] mr-1.5"
        ></span>
        "When do you want us to start building?"
      </p>
      <div
        aria-hidden="true"
        class="absolute bottom-[5%] left-[58%] h-2.5 w-40 -rotate-3 rounded-full bg-(--amigos-blue) opacity-70 blur-[1px] motion-safe:animate-amigos-in"
      >
      </div>
      <p class="absolute bottom-[8%] left-[64%] text-[10px] font-medium motion-safe:animate-amigos-in">
        <span
          aria-hidden="true"
          class="inline-block size-2 rounded-full bg-(--amigos-blue) ring-1 ring-base-content/70 -ml-[13px] mr-1.5"
        ></span>
        a blue smear, where Tobias is tackled
      </p>
      <p class="sr-only">{@blueprint.summary}</p>
    </div>
    """
  end

  # -- the layers whose arrows point forward, one per beat --------------------

  attr :beat, :integer, required: true

  defp forward_notes(assigns) do
    assigns =
      assign(assigns,
        layers: on_page(~w(buster_mexico planted_foreshadowing oscar)a, assigns.beat)
      )

    ~H"""
    <div class="absolute top-[84%] left-1/2 -translate-x-1/2 w-[min(44rem,60%)] grid grid-cols-3 gap-x-3">
      <.note :for={layer <- @layers} layer={layer} clamp />
    </div>
    """
  end

  # -- the silent film, and the Spanish ---------------------------------------

  defp insert(assigns) do
    assigns = assign(assigns, spanish: Amigos.layer!(:spanish))

    ~H"""
    <figure
      id="layer-spanish"
      class="absolute top-[27%] left-1/2 -translate-x-1/2 z-20 w-[min(22rem,64%)] border-4 border-double border-neutral-content/60 bg-neutral text-neutral-content grayscale px-4 py-3 shadow-xl motion-safe:animate-amigos-slide"
    >
      <p class="text-center font-serif italic text-sm">The Chicken Dance, as understood in Mexico</p>
      <p class="mt-2 text-[11px] leading-snug">
        Black and white, silent, cast with faces you have seen before. A pistol goes off; someone in the background falls.
      </p>
      <figcaption class="mt-2 border-t border-neutral-content/30 pt-2 text-[11px] leading-snug">
        {@spanish.summary}
      </figcaption>
    </figure>
    """
  end

  # -- annotations on annotations, one per beat -------------------------------

  attr :beat, :integer, required: true

  defp overload(assigns) do
    assigns =
      assign(assigns,
        pins:
          for(
            {id, on, place} <- @overload,
            on?(id, assigns.beat),
            do: {Amigos.layer!(id), Amigos.layer!(on), place}
          )
      )

    ~H"""
    <aside
      :for={{layer, on, place} <- @pins}
      id={"layer-#{layer.id}"}
      class={[
        "absolute z-30 w-[min(15rem,44%)] border border-base-content/25 bg-base-200/95 px-2 py-1.5 text-[10px] leading-snug shadow-md motion-safe:animate-amigos-in",
        place
      ]}
    >
      <span
        aria-hidden="true"
        class="absolute -top-2 left-1/3 h-4 w-14 -rotate-6 bg-base-content/35 shadow-sm"
      ></span>
      <p class="font-mono text-[9px] uppercase tracking-widest text-base-content/50">re: {on.name}</p>
      <p><span class="font-semibold">{layer.name}.</span> {layer.summary}</p>
    </aside>
    """
  end

  # -- shared -----------------------------------------------------------------

  # Whether a layer is on the stage yet: it arrives on its first beat.
  defp on?(id, beat), do: Amigos.first_beat(Amigos.layer!(id)) <= beat

  defp on_page(ids, beat), do: ids |> Enum.filter(&on?(&1, beat)) |> Enum.map(&Amigos.layer!/1)

  attr :layer, :map, required: true
  attr :clamp, :boolean, default: false

  defp note(assigns) do
    ~H"""
    <p
      id={"layer-#{@layer.id}"}
      class={[
        "text-[10px] sm:text-[11px] leading-snug text-base-content/75 motion-safe:animate-amigos-in",
        @clamp && "line-clamp-4"
      ]}
    >
      <span class="font-semibold text-base-content">{@layer.name}.</span> {@layer.summary}
    </p>
    """
  end
end
