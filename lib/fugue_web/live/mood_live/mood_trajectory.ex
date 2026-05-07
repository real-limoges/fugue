defmodule FugueWeb.MoodLive.MoodTrajectory do
  @moduledoc """
  PCA-projected trajectory hero viz. Every day is a dot; consecutive days are
  connected with a cluster-colored segment. Replaces the former
  `MoodTrajectory` JS hook.

  Annotations (personal milestones) are overlaid with alternating above/below
  label positions and a dark stroke halo (`paint-order: stroke`) in place of
  the runtime-measured text background the JS used to compute.
  """

  use Phoenix.Component

  alias FugueWeb.MoodLive.{SvgMath, Tooltip}

  @width 900
  @height 520
  @m_top 24
  @m_right 24
  @m_bottom 24
  @m_left 24
  @inner_w @width - @m_left - @m_right
  @inner_h @height - @m_top - @m_bottom

  attr :points, :list, default: []
  attr :annotations, :list, default: []
  attr :cluster_colors, :map, default: %{}
  attr :cluster_names, :map, default: %{}
  attr :selected_day, :any, default: nil

  def trajectory(assigns) do
    focus_date =
      case assigns.selected_day do
        %{date: d} when is_binary(d) -> d
        _ -> nil
      end

    pts = assigns.points

    {segments, dots, annotation_markers} =
      if length(pts) < 2 do
        {[], [], []}
      else
        {x_fn, y_fn} = compute_scales(pts)

        segments =
          pts
          |> Enum.chunk_every(2, 1, :discard)
          |> Enum.map(fn [a, b] ->
            color = (b[:cluster] || b["cluster"]) |> color_for(assigns.cluster_colors)

            %{
              x1: x_fn.(val(a, :x)),
              y1: y_fn.(val(a, :y)),
              x2: x_fn.(val(b, :x)),
              y2: y_fn.(val(b, :y)),
              stroke: color
            }
          end)

        dots =
          Enum.map(pts, fn p ->
            cluster = val(p, :cluster)
            date = val(p, :date)
            cluster_name = (cluster && Map.get(assigns.cluster_names, cluster, cluster)) || "--"
            color = color_for(cluster, assigns.cluster_colors)

            %{
              cx: x_fn.(val(p, :x)),
              cy: y_fn.(val(p, :y)),
              date: date,
              color: color,
              focused?: date == focus_date,
              tooltip:
                ~s|<strong>#{date}</strong><div style="color:#{color}">#{cluster_name}</div>|
            }
          end)

        point_by_date = Map.new(pts, &{val(&1, :date), &1})

        annotation_markers =
          assigns.annotations
          |> Enum.map(&resolve_annotation(&1, point_by_date))
          |> Enum.reject(&is_nil/1)
          |> Enum.sort_by(& &1.date)
          |> Enum.with_index()
          |> Enum.map(fn {a, i} ->
            px = x_fn.(val(a.point, :x))
            py = y_fn.(val(a.point, :y))
            above? = rem(i, 2) == 0
            dy = if above?, do: -28, else: 28
            dx = 14

            cluster = val(a.point, :cluster)
            color = color_for(cluster, assigns.cluster_colors)
            cluster_name = cluster && Map.get(assigns.cluster_names, cluster, cluster)

            %{
              px: px,
              py: py,
              label_x: px + dx,
              label_y: py + dy,
              text_x: px + dx + 4,
              text_y: py + dy,
              label: a.label,
              date: a.date,
              tooltip: annotation_tooltip(a, cluster_name, color)
            }
          end)

        {segments, dots, annotation_markers}
      end

    assigns =
      assign(assigns,
        segments: segments,
        dots: dots,
        annotation_markers: annotation_markers,
        svg_width: @width,
        svg_height: @height,
        g_transform: "translate(#{@m_left},#{@m_top})"
      )

    ~H"""
    <Tooltip.container id="mood-trajectory" style="width: 100%;">
      <svg
        viewBox={"0 0 #{@svg_width} #{@svg_height}"}
        preserveAspectRatio="xMidYMid meet"
        style="display: block; width: 100%;"
      >
        <defs>
          <filter id="traj-glow" x="-50%" y="-50%" width="200%" height="200%">
            <feGaussianBlur stdDeviation="1.6" result="blur" />
            <feMerge>
              <feMergeNode in="blur" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        </defs>

        <g transform={@g_transform}>
          <g>
            <%= for seg <- @segments do %>
              <line
                x1={SvgMath.fmt(seg.x1)}
                y1={SvgMath.fmt(seg.y1)}
                x2={SvgMath.fmt(seg.x2)}
                y2={SvgMath.fmt(seg.y2)}
                stroke={seg.stroke}
                stroke-opacity="0.55"
                stroke-width="1.25"
                stroke-linecap="round"
              />
            <% end %>
          </g>

          <g>
            <%= for d <- @dots do %>
              <circle
                cx={SvgMath.fmt(d.cx)}
                cy={SvgMath.fmt(d.cy)}
                r={if d.focused?, do: "5", else: "2.2"}
                fill={d.color}
                fill-opacity="0.85"
                filter="url(#traj-glow)"
                stroke={if d.focused?, do: "#fff", else: "none"}
                stroke-width={if d.focused?, do: "1.25", else: "0"}
                stroke-opacity={if d.focused?, do: "0.9", else: "0"}
              />
            <% end %>
          </g>

          <g>
            <%= for d <- @dots do %>
              <circle
                class="traj-hit"
                cx={SvgMath.fmt(d.cx)}
                cy={SvgMath.fmt(d.cy)}
                r="7"
                fill="transparent"
                data-tooltip={d.tooltip}
                phx-click="day_selected"
                phx-value-date={d.date}
                style="cursor: crosshair;"
              />
            <% end %>
          </g>

          <g class="trajectory-annotations">
            <%= for a <- @annotation_markers do %>
              <line
                x1={SvgMath.fmt(a.px)}
                y1={SvgMath.fmt(a.py)}
                x2={SvgMath.fmt(a.label_x)}
                y2={SvgMath.fmt(a.label_y)}
                stroke="rgba(255,255,255,0.45)"
                stroke-width="0.75"
                pointer-events="none"
              />
              <text
                x={SvgMath.fmt(a.text_x)}
                y={SvgMath.fmt(a.text_y)}
                text-anchor="start"
                dominant-baseline="middle"
                font-size="10.5px"
                font-family="ui-serif, Georgia, serif"
                font-style="italic"
                paint-order="stroke"
                stroke="rgba(10,10,26,0.65)"
                stroke-width="3"
                stroke-linejoin="round"
                fill="rgba(255,255,255,0.92)"
                pointer-events="none"
              >
                {a.label}
              </text>
              <circle
                cx={SvgMath.fmt(a.px)}
                cy={SvgMath.fmt(a.py)}
                r="4"
                fill="none"
                stroke="#fff"
                stroke-width="1.25"
                stroke-opacity="0.9"
                pointer-events="none"
              />
              <circle
                class="annotation-hit"
                cx={SvgMath.fmt(a.px)}
                cy={SvgMath.fmt(a.py)}
                r="10"
                fill="transparent"
                data-tooltip={a.tooltip}
                phx-click="day_selected"
                phx-value-date={a.date}
                style="cursor: pointer;"
              />
            <% end %>
          </g>
        </g>
      </svg>
    </Tooltip.container>
    """
  end

  # --- Geometry helpers ---

  defp compute_scales(points) do
    xs = Enum.map(points, &val(&1, :x)) |> Enum.map(&(&1 * 1.0))
    ys = Enum.map(points, &val(&1, :y)) |> Enum.map(&(&1 * 1.0))

    x_min = Enum.min(xs)
    x_max = Enum.max(xs)
    y_min = Enum.min(ys)
    y_max = Enum.max(ys)

    x_pad = max((x_max - x_min) * 0.08, 1.0)
    y_pad = max((y_max - y_min) * 0.08, 1.0)

    data_w = x_max - x_min + 2 * x_pad
    data_h = y_max - y_min + 2 * y_pad
    fit = min(@inner_w / data_w, @inner_h / data_h)

    x_mid = (x_min + x_max) / 2
    y_mid = (y_min + y_max) / 2

    x_domain_lo = x_mid - data_w / 2
    x_range_lo = (@inner_w - data_w * fit) / 2

    y_domain_hi = y_mid + data_h / 2
    y_range_lo = (@inner_h - data_h * fit) / 2

    x_fn = fn v -> x_range_lo + (v - x_domain_lo) * fit end
    # SVG y grows downward; trajectory's y_max should map to the TOP of the inner area.
    y_fn = fn v -> y_range_lo + (y_domain_hi - v) * fit end

    {x_fn, y_fn}
  end

  defp color_for(nil, _), do: "#888"
  defp color_for(cluster, colors), do: Map.get(colors, cluster, "#888")

  defp val(p, key) when is_map(p) do
    Map.get(p, key) || Map.get(p, to_string(key))
  end

  defp resolve_annotation(a, point_by_date) do
    date = val(a, :date)

    case Map.get(point_by_date, date) do
      nil ->
        nil

      point ->
        %{
          date: date,
          label: val(a, :label),
          note: val(a, :note),
          point: point
        }
    end
  end

  defp annotation_tooltip(a, cluster_name, color) do
    note_html =
      case a.note do
        note when is_binary(note) and note != "" ->
          ~s|<div style="margin-top:4px;color:#ddd;white-space:normal;max-width:240px">#{note}</div>|

        _ ->
          ""
      end

    cluster_html =
      if cluster_name do
        ~s|<div style="margin-top:4px;color:#{color}">#{cluster_name}</div>|
      else
        ""
      end

    ~s|<div style="font-style:italic;font-family:ui-serif,Georgia,serif;font-size:12px">#{a.label}</div>| <>
      ~s|<div style="color:#888;font-size:10px;margin-top:1px">#{a.date}</div>| <>
      note_html <> cluster_html
  end
end
