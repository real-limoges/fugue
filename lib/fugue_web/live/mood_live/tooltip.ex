defmodule FugueWeb.MoodLive.Tooltip do
  @moduledoc """
  Wrapper for cursor-following tooltip surfaces used across /mood components.
  Pairs the `HoverTooltip` (default) or `CalendarTooltip` JS hook with a
  positioned div. Under `HoverTooltip`, child SVGs/elements set
  `data-tooltip` to provide the server-rendered HTML the hook displays on
  hover; `CalendarTooltip` builds its HTML from compact per-cell data
  instead (see `FugueWeb.MoodLive.CalendarGrid`).
  """

  use Phoenix.Component

  attr :id, :string, required: true
  attr :hook, :string, default: "HoverTooltip"
  attr :class, :string, default: nil
  attr :style, :string, default: ""
  attr :rest, :global, include: ~w(data-clusters)
  slot :inner_block, required: true

  # The card is server-rendered and ignored by patches, so the hook only
  # fills and positions it; a patch to the container can't drop it.
  # CalendarTooltip anchors its card to the right edge.
  def container(assigns) do
    assigns =
      assign(assigns, :card_class, [
        "tooltip-card",
        assigns.hook == "CalendarTooltip" && "tooltip-card--right"
      ])

    ~H"""
    <div id={@id} phx-hook={@hook} class={@class} style={"position: relative; #{@style}"} {@rest}>
      {render_slot(@inner_block)}
      <div id={"#{@id}-tip"} class={@card_class} data-tooltip-card phx-update="ignore"></div>
    </div>
    """
  end

  # --- Cards ---
  #
  # Each card is a HEEx template rendered to a string for a `data-tooltip`
  # attribute, so names, labels and notes are escaped like any other markup.
  # A cluster color is the one inline style, since it is a value, not a class.

  @doc "A title, an optional detail after it, and a cluster name in its color."
  @spec cluster_line(String.t(), String.t() | :none, String.t(), String.t()) :: String.t()
  def cluster_line(title, detail, color, cluster_name) do
    to_html(cluster_line_card(%{title: title, detail: detail, color: color, name: cluster_name}))
  end

  @doc "A trajectory annotation: its label, date, optional note and cluster."
  @spec annotation(map(), String.t() | :none, String.t()) :: String.t()
  def annotation(annotation, cluster_name, color) do
    to_html(
      annotation_card(%{
        label: annotation.label,
        date: annotation.date,
        note: annotation.note,
        name: cluster_name,
        color: color
      })
    )
  end

  @doc """
  A month on the season ring: its label, its day count, and one row per
  cluster with `:color`, `:name`, `:count` and `:pct`.
  """
  @spec season_month(String.t(), non_neg_integer(), [map()]) :: String.t()
  def season_month(label, total, rows) do
    to_html(season_month_card(%{label: label, total: total, rows: rows}))
  end

  @doc "A month's flower: its label, cluster, dimension averages and entry count."
  @spec flower(String.t(), String.t(), String.t(), [{String.t(), float()}], pos_integer()) ::
          String.t()
  def flower(label, color, cluster_name, dims, count) do
    to_html(
      flower_card(%{label: label, color: color, name: cluster_name, dims: dims, count: count})
    )
  end

  defp to_html(rendered), do: rendered |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()

  defp cluster_line_card(assigns) do
    ~H"""
    <strong>{@title}</strong><span :if={@detail != :none}> · {@detail}</span>
    <div style={"color: #{@color}"}>{@name}</div>
    """
  end

  defp annotation_card(assigns) do
    ~H"""
    <div class="italic font-serif text-[12px]">{@label}</div>
    <div class="text-(--mood-ink-3) text-[10px] mt-px">{@date}</div>
    <div
      :if={is_binary(@note) and @note != ""}
      class="mt-1 text-(--mood-ink-1) whitespace-normal max-w-60"
    >
      {@note}
    </div>
    <div :if={@name != :none} class="mt-1" style={"color: #{@color}"}>{@name}</div>
    """
  end

  defp season_month_card(assigns) do
    ~H"""
    <strong class="text-[13px]">{@label}</strong>
    <div class="text-(--mood-ink-4) text-[10px] mb-1.5">{@total} days across all years</div>
    <div class="grid grid-cols-[auto_auto_auto] gap-x-2.5 gap-y-px">
      <%= for row <- @rows do %>
        <span class="inline-flex items-center gap-[3px]">
          <span class="inline-block size-1.5 rounded-full" style={"background: #{row.color}"}></span>
          {row.name}
        </span>
        <span class="text-(--mood-ink-3) text-right">{row.count}d</span>
        <strong>{row.pct}%</strong>
      <% end %>
    </div>
    """
  end

  defp flower_card(assigns) do
    ~H"""
    <strong class="text-[13px]">{@label}</strong>
    <div class="text-[11px] mt-0.5 font-semibold" style={"color: #{@color}"}>{@name}</div>
    <div class="mt-1.5 grid grid-cols-[auto_auto] gap-x-3.5 gap-y-px">
      <%= for {dim, value} <- @dims do %>
        <span class="text-(--mood-ink-3)">{dim}</span>
        <strong>{:erlang.float_to_binary(value * 1.0, decimals: 1)}</strong>
      <% end %>
    </div>
    <div class="mt-1 text-(--mood-ink-4) text-[10px]">
      {@count} {if @count == 1, do: "entry", else: "entries"}
    </div>
    """
  end
end
