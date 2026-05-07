defmodule FugueWeb.MoodLive.Tooltip do
  @moduledoc """
  Wrapper for cursor-following tooltip surfaces used across /mood components.
  Pairs the `HoverTooltip` (default) or `CalendarTooltip` JS hook with a
  positioned div; child SVGs/elements set `data-tooltip` to provide the
  server-rendered HTML the hook displays on hover.
  """

  use Phoenix.Component

  attr :id, :string, required: true
  attr :hook, :string, default: "HoverTooltip"
  attr :class, :string, default: nil
  attr :style, :string, default: ""
  slot :inner_block, required: true

  def container(assigns) do
    ~H"""
    <div id={@id} phx-hook={@hook} class={@class} style={"position: relative; #{@style}"}>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
