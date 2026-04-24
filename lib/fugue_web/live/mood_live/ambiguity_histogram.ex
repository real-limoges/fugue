defmodule FugueWeb.MoodLive.AmbiguityHistogram do
  @moduledoc """
  Server-rendered histogram of max-membership values (how decisively clusters
  claim each day). Replaces the former `AmbiguityHistogram` JS hook.
  """

  use Phoenix.Component

  @width 800
  @height 140
  @m_top 14
  @m_right 15
  @m_bottom 28
  @m_left 36
  @inner_w @width - @m_left - @m_right
  @inner_h @height - @m_top - @m_bottom

  attr :bins, :list, default: []
  attr :threshold, :float, default: 0.45

  def histogram(assigns) do
    bins = assigns.bins

    {bars, threshold_x, x_ticks, y_ticks} =
      if bins == [] do
        {[], 0, [], []}
      else
        x0 = List.first(bins).x0 * 1.0
        x1 = List.last(bins).x1 * 1.0
        x_span = max(x1 - x0, 1.0e-9)

        max_count = Enum.max_by(bins, & &1.count).count
        y_max = nice_ceiling(max_count)

        x_px = fn v -> (v - x0) / x_span * @inner_w end
        y_px = fn v -> @inner_h - v / y_max * @inner_h end

        bars =
          Enum.map(bins, fn b ->
            x_left = x_px.(b.x0)
            x_right = x_px.(b.x1)
            y_top = y_px.(b.count)

            %{
              x: x_left,
              width: max(x_right - x_left - 1, 0),
              y: y_top,
              height: @inner_h - y_top,
              fill: if(b.x1 <= assigns.threshold, do: "#e6a542", else: "rgba(255,255,255,0.35)")
            }
          end)

        x_ticks =
          for t <- 0..6, v = x0 + t / 6 * x_span, do: %{x: x_px.(v), label: "#{round(v * 100)}%"}

        y_ticks =
          for t <- 0..3, v = t / 3 * y_max do
            %{y: y_px.(v), label: Integer.to_string(round(v))}
          end

        {bars, x_px.(assigns.threshold), x_ticks, y_ticks}
      end

    assigns =
      assign(assigns,
        bars: bars,
        threshold_x: threshold_x,
        x_ticks: x_ticks,
        y_ticks: y_ticks,
        svg_width: @width,
        svg_height: @height,
        inner_w: @inner_w,
        inner_h: @inner_h,
        g_transform: "translate(#{@m_left},#{@m_top})"
      )

    ~H"""
    <div id="ambiguity-histogram" style="width: 100%;">
      <svg
        viewBox={"0 0 #{@svg_width} #{@svg_height}"}
        preserveAspectRatio="xMidYMid meet"
        style="width: 100%;"
      >
        <g transform={@g_transform}>
          <rect
            x="0"
            y="0"
            width={fmt(@threshold_x)}
            height={@inner_h}
            fill="rgba(230,165,66,0.06)"
          />

          <%= for b <- @bars do %>
            <rect
              x={fmt(b.x)}
              y={fmt(b.y)}
              width={fmt(b.width)}
              height={fmt(b.height)}
              fill={b.fill}
              fill-opacity="0.7"
            />
          <% end %>

          <line
            x1={fmt(@threshold_x)}
            x2={fmt(@threshold_x)}
            y1="0"
            y2={@inner_h}
            stroke="#e6a542"
            stroke-width="1"
            stroke-dasharray="4,3"
            stroke-opacity="0.8"
          />

          <text
            x={fmt(@threshold_x - 4)}
            y="6"
            text-anchor="end"
            fill="#e6a542"
            font-size="9px"
            font-weight="600"
          >
            in-between
          </text>
          <text
            x={fmt(@threshold_x + 4)}
            y="6"
            text-anchor="start"
            fill="#888"
            font-size="9px"
            font-weight="600"
          >
            decisive
          </text>

          <g transform={"translate(0,#{@inner_h})"}>
            <line x1="0" y1="0" x2={@inner_w} y2="0" stroke="#444" />
            <%= for t <- @x_ticks do %>
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

          <text
            x={fmt(@inner_w / 2)}
            y={@inner_h + 24}
            text-anchor="middle"
            fill="#555"
            font-size="9px"
          >
            strongest cluster membership
          </text>

          <g>
            <line x1="0" y1="0" x2="0" y2={@inner_h} stroke="#444" />
            <%= for t <- @y_ticks do %>
              <line x1="-3" y1={fmt(t.y)} x2="0" y2={fmt(t.y)} stroke="#444" />
              <text
                x="-5"
                y={fmt(t.y + 3)}
                text-anchor="end"
                fill="#666"
                font-size="9px"
              >
                {t.label}
              </text>
            <% end %>
          </g>
        </g>
      </svg>
    </div>
    """
  end

  # Round up to a "nice" value: 1, 2, 5, 10, 20, 50, 100, ...
  defp nice_ceiling(0), do: 1

  defp nice_ceiling(n) when n > 0 do
    exponent = :math.floor(:math.log10(n * 1.0))
    pow10 = :math.pow(10, exponent)
    fraction = n / pow10

    nice =
      cond do
        fraction <= 1 -> 1
        fraction <= 2 -> 2
        fraction <= 5 -> 5
        true -> 10
      end

    round(nice * pow10)
  end

  defp fmt(n) when is_integer(n), do: Integer.to_string(n)
  defp fmt(n) when is_float(n), do: :erlang.float_to_binary(n, [:compact, decimals: 2])
end
