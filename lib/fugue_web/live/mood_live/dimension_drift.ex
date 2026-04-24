defmodule FugueWeb.MoodLive.DimensionDrift do
  @moduledoc """
  Small-multiples sparklines — 90-day rolling average per dimension, showing
  long-term drift. Replaces the former `DimensionDrift` JS hook.
  """

  use Phoenix.Component

  alias FugueWeb.MoodLive.SvgMath

  @width 800
  @m_top 6
  @m_right 15
  @m_bottom 24
  @m_left 72
  @row_h 44
  @gap 8

  @dim_colors %{
    "sleep" => "#42c8e6",
    "anxiety" => "#e44dbc",
    "sensitivity" => "#a86ee6",
    "outlook" => "#6ee64d",
    "speed" => "#e6a542"
  }

  attr :dimensions, :list, default: []

  def drift(assigns) do
    dims = assigns.dimensions
    inner_w = @width - @m_left - @m_right

    {rows, x_ticks, total_h, axis_y} =
      if dims == [] do
        {[], [], 100, 0}
      else
        dates = Enum.map(List.first(dims).series, & &1.date)
        {min_d, max_d} = date_range(dates)
        span = max(Date.diff(max_d, min_d), 1)

        x_fn = fn d -> Date.diff(Date.from_iso8601!(d), min_d) / span * inner_w end

        rows =
          Enum.with_index(dims)
          |> Enum.map(fn {dim, i} ->
            color = Map.get(@dim_colors, dim.dimension, "#888")
            values = Enum.map(dim.series, & &1.value)
            y_min = Enum.min(values)
            y_max = Enum.max(values)
            y_pad = max((y_max - y_min) * 0.15, 0.5)
            domain_lo = y_min - y_pad
            domain_hi = y_max + y_pad
            domain_span = max(domain_hi - domain_lo, 1.0e-9)

            y_fn = fn v ->
              @row_h - (v - domain_lo) / domain_span * @row_h
            end

            points = Enum.map(dim.series, fn p -> {x_fn.(p.date), y_fn.(p.value)} end)
            mean = Enum.sum(values) / length(values)
            first_val = List.first(values)
            last_val = List.last(values)

            %{
              dimension: dim.dimension,
              color: color,
              row_y: @m_top + i * (@row_h + @gap),
              path_d: SvgMath.basis_path(points),
              mean_y: y_fn.(mean),
              first_val: first_val,
              first_y: y_fn.(first_val),
              last_val: last_val,
              last_y: y_fn.(last_val),
              label_y: @m_top + i * (@row_h + @gap) + @row_h / 2
            }
          end)

        total_h = @m_top + @m_bottom + length(dims) * (@row_h + @gap) - @gap
        axis_y = @m_top + length(dims) * (@row_h + @gap) - @gap

        x_ticks =
          for y <- min_d.year..max_d.year,
              jan1 = Date.new!(y, 1, 1),
              Date.compare(jan1, min_d) != :lt and Date.compare(jan1, max_d) != :gt do
            %{x: x_fn.(Date.to_iso8601(jan1)), label: Integer.to_string(y)}
          end

        {rows, x_ticks, total_h, axis_y}
      end

    assigns =
      assign(assigns,
        rows: rows,
        x_ticks: x_ticks,
        svg_width: @width,
        svg_height: total_h,
        axis_y: axis_y,
        inner_w: inner_w,
        row_h: @row_h,
        m_left: @m_left,
        label_x: @m_left - 8,
        axis_transform: "translate(#{@m_left},#{axis_y})"
      )

    ~H"""
    <div id="dimension-drift" style="width: 100%;">
      <svg
        viewBox={"0 0 #{@svg_width} #{@svg_height}"}
        preserveAspectRatio="xMidYMid meet"
        style="width: 100%;"
      >
        <%= for row <- @rows do %>
          <g transform={"translate(#{@m_left},#{SvgMath.fmt(row.row_y)})"}>
            <rect width={@inner_w} height={@row_h} fill="rgba(255,255,255,0.015)" rx="3" />
            <line
              x1="0"
              x2={@inner_w}
              y1={SvgMath.fmt(row.mean_y)}
              y2={SvgMath.fmt(row.mean_y)}
              stroke="rgba(255,255,255,0.08)"
              stroke-width="0.5"
              stroke-dasharray="3,3"
            />
            <path
              d={row.path_d}
              fill="none"
              stroke={row.color}
              stroke-width="1.5"
              stroke-opacity="0.8"
            />
            <text
              x="-2"
              y={SvgMath.fmt(row.first_y)}
              text-anchor="end"
              dominant-baseline="central"
              fill="#444"
              font-size="8px"
            >
              {num(row.first_val)}
            </text>
            <text
              x={@inner_w + 4}
              y={SvgMath.fmt(row.last_y)}
              dominant-baseline="central"
              fill="#555"
              font-size="8px"
            >
              {num(row.last_val)}
            </text>
          </g>

          <text
            x={@label_x}
            y={SvgMath.fmt(row.label_y)}
            text-anchor="end"
            dominant-baseline="central"
            fill={row.color}
            font-size="10px"
            font-weight="600"
          >
            {row.dimension}
          </text>
        <% end %>

        <g transform={@axis_transform}>
          <line x1="0" y1="0" x2={@inner_w} y2="0" stroke="#444" />
          <%= for t <- @x_ticks do %>
            <line x1={SvgMath.fmt(t.x)} y1="0" x2={SvgMath.fmt(t.x)} y2="3" stroke="#444" />
            <text
              x={SvgMath.fmt(t.x)}
              y="16"
              text-anchor="middle"
              fill="#666"
              font-size="10px"
            >
              {t.label}
            </text>
          <% end %>
        </g>
      </svg>
    </div>
    """
  end

  defp num(v) when is_float(v), do: :erlang.float_to_binary(v, decimals: 1)
  defp num(v), do: to_string(v)

  defp date_range([first | _] = dates) do
    parsed = Enum.map(dates, &Date.from_iso8601!/1)
    {Enum.min(parsed, Date), Enum.max(parsed, Date)}
  rescue
    _ -> {Date.from_iso8601!(first), Date.from_iso8601!(first)}
  end
end
