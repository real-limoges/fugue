defmodule FugueWeb.MoodLive.DimensionDistributions do
  @moduledoc """
  Per-cluster ridge distributions: one row per dimension; each row shows
  overlapping translucent KDE curves (one per cluster) plus an overall
  reference. Replaces the former `DimensionDistributions` JS hook.

  KDE and basis smoothing run in Elixir; the SVG is responsive via viewBox.
  """

  use Phoenix.Component

  alias FugueWeb.MoodLive.SvgMath

  @row_h 92
  @label_w 90
  @m_top 10
  @m_right 28
  @m_bottom 10
  @m_left 12
  @chart_w 640
  @sample_points 80
  @bandwidth_frac 0.07

  @dim_colors %{
    "sleep" => "#42c8e6",
    "anxiety" => "#e44dbc",
    "sensitivity" => "#a86ee6",
    "outlook" => "#6ee64d",
    "speed" => "#e6a542"
  }

  @dim_domains %{
    "sleep" => {0, 15},
    "outlook" => {0, 10},
    "speed" => {0, 10},
    "anxiety" => {0, 5},
    "sensitivity" => {0, 5}
  }

  @dim_ticks %{
    "sleep" => [0, 3, 6, 9, 12, 15],
    "outlook" => [0, 2, 4, 6, 8, 10],
    "speed" => [0, 2, 4, 6, 8, 10],
    "anxiety" => [0, 1, 2, 3, 4, 5],
    "sensitivity" => [0, 1, 2, 3, 4, 5]
  }

  @fallback_domain {0, 10}
  @fallback_ticks [0, 2, 4, 6, 8, 10]

  attr :points, :list, default: []
  attr :dimensions, :list, default: []
  attr :clusters, :list, default: []

  def distributions(assigns) do
    rows =
      Enum.with_index(assigns.dimensions)
      |> Enum.map(fn {dim, i} ->
        build_row(dim, i, assigns.points, assigns.clusters)
      end)

    svg_width = @label_w + @m_left + @chart_w + @m_right
    total_h = @m_top + length(assigns.dimensions) * @row_h + @m_bottom

    assigns =
      assign(assigns,
        rows: rows,
        svg_width: svg_width,
        svg_height: total_h,
        chart_w: @chart_w,
        label_w: @label_w,
        g_x: @label_w + @m_left
      )

    ~H"""
    <div id="dimension-distributions" style="width: 100%;">
      <svg
        viewBox={"0 0 #{@svg_width} #{@svg_height}"}
        preserveAspectRatio="xMidYMid meet"
        style="width: 100%; height: auto;"
      >
        <%= for row <- @rows do %>
          <%= unless row.empty? do %>
            <text
              x={@label_w - 10}
              y={SvgMath.fmt(row.label_y)}
              text-anchor="end"
              dominant-baseline="middle"
              fill={row.label_color}
              font-size="12px"
              font-weight="600"
            >
              {row.dim}
            </text>

            <g transform={"translate(#{@g_x},0)"}>
              <line
                x1="0"
                x2={@chart_w}
                y1={SvgMath.fmt(row.plot_bottom)}
                y2={SvgMath.fmt(row.plot_bottom)}
                stroke="rgba(255,255,255,0.1)"
                stroke-width="1"
              />

              <path
                d={row.overall_d}
                fill="none"
                stroke="rgba(255,255,255,0.28)"
                stroke-width="1"
                stroke-dasharray="2 3"
              />

              <%= for c <- row.cluster_areas do %>
                <path
                  d={c.d}
                  fill={c.color}
                  fill-opacity="0.22"
                  stroke={c.color}
                  stroke-width="1.5"
                  stroke-opacity="0.9"
                />
              <% end %>
            </g>

            <g transform={"translate(#{@g_x},#{SvgMath.fmt(row.axis_y)})"}>
              <%= for t <- row.ticks do %>
                <line
                  x1={SvgMath.fmt(t.x)}
                  x2={SvgMath.fmt(t.x)}
                  y1="0"
                  y2="4"
                  stroke="rgba(255,255,255,0.25)"
                  stroke-width="1"
                />
                <text
                  x={SvgMath.fmt(t.x)}
                  y="15"
                  text-anchor={t.anchor}
                  fill="#6b7280"
                  font-size="10px"
                >
                  {t.label}
                </text>
              <% end %>
            </g>
          <% end %>
        <% end %>
      </svg>
    </div>
    """
  end

  # --- Row building ---

  defp build_row(dim, i, points, clusters) do
    row_top = @m_top + i * @row_h
    plot_top = row_top + 10
    plot_bottom = row_top + @row_h - 28

    all_values =
      points
      |> Enum.map(&get_in(&1, [:dimensions, dim]))
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&(&1 * 1.0))

    if all_values == [] do
      %{dim: dim, empty?: true}
    else
      {d_lo, d_hi} = Map.get(@dim_domains, dim, @fallback_domain)
      bandwidth = max((d_hi - d_lo) * @bandwidth_frac, 0.05)
      overall_curve = density_curve(all_values, {d_lo, d_hi}, bandwidth)

      cluster_curves =
        Enum.map(clusters, fn c ->
          vals =
            points
            |> Enum.filter(&(&1.cluster == c.id))
            |> Enum.map(&get_in(&1, [:dimensions, dim]))
            |> Enum.reject(&is_nil/1)
            |> Enum.map(&(&1 * 1.0))

          %{cluster: c, curve: density_curve(vals, {d_lo, d_hi}, bandwidth), n: length(vals)}
        end)

      max_density =
        [curve_max(overall_curve) | Enum.map(cluster_curves, &curve_max(&1.curve))]
        |> Enum.max(fn -> 1.0 end)
        |> max(1.0e-9)

      x_fn = fn v -> (v - d_lo) / max(d_hi - d_lo, 1.0e-9) * @chart_w end
      y_fn = fn d -> plot_bottom - d / max_density * (plot_bottom - plot_top) end

      curve_points = fn curve -> Enum.map(curve, fn [x, y] -> {x_fn.(x), y_fn.(y)} end) end

      ticks_vals = Map.get(@dim_ticks, dim, @fallback_ticks)
      last_idx = length(ticks_vals) - 1

      ticks =
        ticks_vals
        |> Enum.with_index()
        |> Enum.map(fn {v, idx} ->
          anchor =
            cond do
              idx == 0 -> "start"
              idx == last_idx -> "end"
              true -> "middle"
            end

          %{x: x_fn.(v), anchor: anchor, label: format_tick(v)}
        end)

      overall_d = SvgMath.basis_path(curve_points.(overall_curve))

      cluster_areas =
        cluster_curves
        |> Enum.sort_by(& &1.n, :desc)
        |> Enum.map(fn %{cluster: c, curve: curve} ->
          pts = curve_points.(curve)
          d = area_closed_path(pts, plot_bottom)
          %{color: c.color, d: d}
        end)

      %{
        dim: dim,
        empty?: false,
        label_color: Map.get(@dim_colors, dim, "#aaa"),
        label_y: (plot_top + plot_bottom) / 2,
        plot_bottom: plot_bottom,
        axis_y: plot_bottom + 2,
        overall_d: overall_d,
        cluster_areas: cluster_areas,
        ticks: ticks
      }
    end
  end

  defp curve_max([]), do: 0.0
  defp curve_max(curve), do: Enum.map(curve, fn [_x, y] -> y end) |> Enum.max()

  # --- KDE ---

  defp density_curve([], _, _), do: []

  defp density_curve(values, {d_lo, d_hi}, bandwidth) do
    kde = fn x ->
      norm = 1 / (:math.sqrt(2 * :math.pi()) * bandwidth)

      sum =
        Enum.reduce(values, 0.0, fn v, acc ->
          z = (x - v) / bandwidth
          acc + :math.exp(-0.5 * z * z)
        end)

      sum / length(values) * norm
    end

    step = (d_hi - d_lo) / @sample_points

    for i <- 0..@sample_points do
      x = d_lo + i * step
      [x, kde.(x)]
    end
  end

  # --- Path helpers ---

  # Build a closed area path that traces a basis curve through the top points,
  # then drops to the baseline and closes.
  defp area_closed_path([], _), do: ""

  defp area_closed_path([{x0, _} | _] = points, baseline_y) do
    {xn, _} = List.last(points)
    top = SvgMath.basis_path(points)

    top <>
      "L#{SvgMath.fmt(xn)},#{SvgMath.fmt(baseline_y)}" <>
      "L#{SvgMath.fmt(x0)},#{SvgMath.fmt(baseline_y)}Z"
  end

  defp format_tick(v) when is_integer(v), do: Integer.to_string(v)
  defp format_tick(v) when is_float(v), do: :erlang.float_to_binary(v, decimals: 1)
end
