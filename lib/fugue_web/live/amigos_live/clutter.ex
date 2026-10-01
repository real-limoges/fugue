defmodule FugueWeb.AmigosLive.Clutter do
  @moduledoc """
  The mess that piles up on top of the `/amigos` stage, beat by beat.

  Three kinds, none with copy of its own:

    * scrawls: each layer's internal connections, handwritten near where
      the layer sits, arriving with the layer;
    * stamps: the episode codes the arrows point to, pressed one per beat
      from beat 8 on, in the order their layers arrived;
    * marks: a highlighter swipe and misprinted copies of the spine, at
      fixed beats near the end.

  Positions are fixed lists, so the mess is the same on every visit. All of
  it sits above the stage's zones and below the overload notes.
  """
  use Phoenix.Component

  alias Fugue.Amigos

  # Where each layer's scrawls go, in the order of its internal connections.
  @scrawl_places %{
    ice_off_duty: ["top-[21%] left-[66%] rotate-6"],
    surveillance: ["top-[30%] left-[9%] -rotate-12"],
    radio: ["top-[40%] right-[6%] rotate-3"],
    silent_film: ["top-[57%] left-[71%] rotate-12"],
    crossed_conversations: ["top-[74%] left-[14%] -rotate-3"],
    hog: ["top-[46%] left-[4%] -rotate-6"],
    ann: ["top-[88%] left-[26%] rotate-[7deg]"],
    offices_props: ["top-[8%] left-[74%] rotate-[18deg]"],
    blueprint: ["top-[27%] left-[57%] -rotate-[20deg]"],
    spanish: ["top-[23%] left-[22%] -rotate-[9deg]"],
    gene: ["bottom-[11%] left-[38%] -rotate-[14deg]"]
  }

  @stamp_places [
    "top-[17%] left-[37%] -rotate-[8deg]",
    "top-[44%] left-[30%] rotate-[14deg]",
    "top-[9%] left-[52%] rotate-[5deg]",
    "top-[60%] left-[44%] -rotate-[22deg]",
    "top-[35%] left-[46%] rotate-[28deg]",
    "bottom-[16%] left-[18%] -rotate-[4deg]",
    "top-[70%] right-[24%] rotate-[9deg]",
    "top-[3%] left-[8%] -rotate-[17deg]",
    "top-[52%] left-[12%] rotate-[21deg]",
    "bottom-[4%] right-[8%] -rotate-[11deg]",
    "top-[13%] right-[12%] rotate-[33deg]",
    "top-[80%] left-[52%] -rotate-[30deg]",
    "top-[39%] left-[60%] -rotate-[2deg]"
  ]

  @stamps_from 8

  # The spine's extra marks, and the beat each arrives on.
  @highlight_from 12
  @misprint_from 16
  @second_misprint_from 19

  attr :beat, :integer, required: true

  def clutter(assigns) do
    assigns =
      assign(assigns,
        scrawls: scrawls(assigns.beat),
        highlight: assigns.beat >= @highlight_from,
        misprint: assigns.beat >= @misprint_from,
        second_misprint: assigns.beat >= @second_misprint_from,
        stamps: stamps(assigns.beat)
      )

    ~H"""
    <div id="amigos-clutter" class="contents">
      <.misprint
        :if={@misprint}
        id="amigos-misprint"
        offset="translate-x-[3px] translate-y-[2px]"
      />
      <.misprint
        :if={@second_misprint}
        id="amigos-misprint-2"
        offset="-translate-x-[5px] -translate-y-[3px] -rotate-1"
      />
      <div
        :if={@highlight}
        id="amigos-highlight"
        aria-hidden="true"
        class="absolute top-[5.2%] left-[24%] h-[2.6%] w-[34%] -rotate-1 rounded-sm bg-neutral/35 mix-blend-multiply motion-safe:animate-amigos-in"
      >
      </div>

      <p
        :for={{text, place} <- @stamps}
        aria-hidden="true"
        class={[
          "amigos-stamp absolute z-20 border-[3px] border-double border-neutral/80 px-2 py-0.5",
          "text-sm sm:text-base uppercase tracking-widest text-neutral/80 motion-safe:animate-amigos-stamp",
          place
        ]}
      >
        {text}
      </p>

      <p
        :for={{note, place} <- @scrawls}
        class={[
          "amigos-scrawl absolute z-20 max-w-48 text-sm sm:text-base leading-tight motion-safe:animate-amigos-in",
          place
        ]}
      >
        {note}
      </p>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :offset, :string, required: true

  # A copy of the spine sentence printed slightly off register.
  defp misprint(assigns) do
    ~H"""
    <p
      id={@id}
      aria-hidden="true"
      class={[
        "absolute top-[5%] left-1/2 -translate-x-1/2 w-[min(40rem,56%)] text-lg sm:text-2xl leading-snug font-medium",
        "pointer-events-none text-(--amigos-blue) opacity-60 motion-safe:animate-amigos-in",
        @offset
      ]}
    >
      Michael tells Gob he has no friends.
    </p>
    """
  end

  # Every internal connection of the layers on the stage, with its place.
  defp scrawls(beat) do
    for layer <- Amigos.revealed_by(beat),
        {connection, place} <-
          Enum.zip(Amigos.connections(layer, :internal), Map.get(@scrawl_places, layer.id, [])),
        do: {connection.note, place}
  end

  # One stamp per beat from @stamps_from, taking episode codes in the order
  # their layers arrived, never more than the layers on stage can supply.
  defp stamps(beat) do
    codes =
      beat
      |> Amigos.revealed_by()
      |> Enum.sort_by(&Amigos.first_beat/1)
      |> Enum.flat_map(&episode_codes/1)
      |> Enum.uniq()

    codes
    |> Enum.take(max(beat - @stamps_from + 1, 0))
    |> Enum.zip(@stamp_places)
  end

  defp episode_codes(layer) do
    for connection <- layer.connections,
        connection.target != nil,
        [code] <- Regex.scan(~r/S\dE\d+|Season \d/, connection.target),
        do: code
  end
end
