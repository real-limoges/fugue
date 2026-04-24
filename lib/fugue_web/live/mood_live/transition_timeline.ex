defmodule FugueWeb.MoodLive.TransitionTimeline do
  @moduledoc """
  Horizontal timeline bar showing contiguous runs of each dominant cluster,
  with white markers at every transition. Replaces the former
  `TransitionTimeline` JS hook.
  """

  use Phoenix.Component

  @width 800
  @height 50
  @m_top 6
  @m_right 15
  @m_left 30
  @inner_w @width - @m_left - @m_right
  @bar_h 18

  attr :segments, :list, default: []
  attr :transitions, :list, default: []
  attr :cluster_colors, :map, default: %{}
  attr :selected_cluster, :any, default: nil

  def timeline(assigns) do
    {blocks, markers, year_ticks} =
      if assigns.segments == [] do
        {[], [], []}
      else
        all_dates =
          Enum.flat_map(assigns.segments, fn s -> [s.start, s.end_date] end)
          |> Enum.map(&Date.from_iso8601!/1)

        min_d = Enum.min(all_dates, Date)
        max_d = Enum.max(all_dates, Date)
        span = max(Date.diff(max_d, min_d), 1)

        x_fn = fn ds ->
          Date.diff(Date.from_iso8601!(ds), min_d) / span * @inner_w
        end

        blocks =
          Enum.map(assigns.segments, fn seg ->
            x0 = x_fn.(seg.start)
            x1 = x_fn.(seg.end_date)
            color = Map.get(assigns.cluster_colors, seg.cluster, "#666")

            %{
              cluster: seg.cluster,
              x: x0,
              width: max(x1 - x0, 1),
              fill: color,
              class: block_class(seg.cluster, assigns.selected_cluster)
            }
          end)

        markers = Enum.map(assigns.transitions, fn t -> %{x: x_fn.(t.date)} end)

        year_ticks =
          for y <- min_d.year..max_d.year,
              jan1 = Date.new!(y, 1, 1),
              Date.compare(jan1, min_d) != :lt and Date.compare(jan1, max_d) != :gt do
            %{x: x_fn.(Date.to_iso8601(jan1)), label: Integer.to_string(y)}
          end

        {blocks, markers, year_ticks}
      end

    assigns =
      assign(assigns,
        blocks: blocks,
        markers: markers,
        year_ticks: year_ticks,
        svg_width: @width,
        svg_height: @height,
        inner_w: @inner_w,
        bar_h: @bar_h,
        g_transform: "translate(#{@m_left},#{@m_top})",
        axis_transform: "translate(0,#{@bar_h + 4})"
      )

    ~H"""
    <div id="transition-timeline" style="width: 100%;">
      <svg
        viewBox={"0 0 #{@svg_width} #{@svg_height}"}
        preserveAspectRatio="xMidYMid meet"
        style="width: 100%;"
      >
        <g transform={@g_transform}>
          <%= for b <- @blocks do %>
            <rect
              class={b.class}
              data-cluster={b.cluster}
              x={fmt(b.x)}
              y="0"
              width={fmt(b.width)}
              height={@bar_h}
              fill={b.fill}
              phx-click="cluster_selected"
              phx-value-cluster={b.cluster}
              style="cursor: pointer;"
            />
          <% end %>

          <%= for m <- @markers do %>
            <line
              x1={fmt(m.x)}
              x2={fmt(m.x)}
              y1="-2"
              y2={@bar_h + 2}
              stroke="#fff"
              stroke-width="1.5"
              stroke-opacity="0.7"
              pointer-events="none"
            />
            <circle
              cx={fmt(m.x)}
              cy={@bar_h / 2}
              r="3"
              fill="#fff"
              fill-opacity="0.9"
              pointer-events="none"
            />
          <% end %>

          <g transform={@axis_transform}>
            <line x1="0" y1="0" x2={@inner_w} y2="0" stroke="#444" />
            <%= for t <- @year_ticks do %>
              <line x1={fmt(t.x)} y1="0" x2={fmt(t.x)} y2="3" stroke="#444" />
              <text
                x={fmt(t.x)}
                y="14"
                text-anchor="middle"
                fill="#666"
                font-size="9px"
              >
                {t.label}
              </text>
            <% end %>
          </g>
        </g>
      </svg>

      <style>
        .tl-segment { fill-opacity: 0.55; transition: fill-opacity 0.2s; }
        .tl-segment.highlight { fill-opacity: 0.8; }
        .tl-segment.dim { fill-opacity: 0.1; }
      </style>
    </div>
    """
  end

  defp block_class(_cluster, nil), do: "tl-segment"
  defp block_class(cluster, cluster), do: "tl-segment highlight"
  defp block_class(_cluster, _selected), do: "tl-segment dim"

  defp fmt(n) when is_integer(n), do: Integer.to_string(n)
  defp fmt(n) when is_float(n), do: :erlang.float_to_binary(n, [:compact, decimals: 2])
end
