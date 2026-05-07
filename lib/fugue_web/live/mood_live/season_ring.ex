defmodule FugueWeb.MoodLive.SeasonRing do
  @moduledoc """
  Polar stacked chart -- cluster dominance by month-of-year, pooled across all
  years. Replaces the former `SeasonRing` JS hook: annular-segment paths are
  generated server-side using SVG's native elliptical-arc (`A`) command.
  """

  use Phoenix.Component

  alias FugueWeb.MoodLive.Tooltip

  @size 420
  @center @size / 2
  @outer_r 155
  @inner_r 35
  @label_r @outer_r + 18
  @month_labels ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)

  attr :months, :list, default: []
  attr :cluster_ids, :list, default: []
  attr :cluster_names, :map, default: %{}
  attr :cluster_colors, :map, default: %{}
  attr :selected_cluster, :any, default: nil

  def ring(assigns) do
    # scaleBand geometry: 12 months across 2π with padding=0.06.
    # Approximation: step = 2π/12 uniformly; each band loses padding on both sides.
    step = :math.pi() * 2 / 12
    pad = step * 0.06
    bandwidth = step - pad

    month_groups =
      Enum.with_index(assigns.months)
      |> Enum.map(fn {m, i} ->
        start_angle = i * step + pad / 2
        end_angle = start_angle + bandwidth

        %{
          index: i,
          label: Enum.at(@month_labels, i),
          label_xy: label_point(start_angle, end_angle),
          start_angle: start_angle,
          end_angle: end_angle,
          total: m.total,
          arcs:
            build_month_arcs(
              m,
              assigns.cluster_ids,
              assigns.cluster_colors,
              start_angle,
              end_angle,
              assigns.selected_cluster
            ),
          empty_path: annular_path(@inner_r, @outer_r, start_angle, end_angle),
          tooltip:
            tooltip_html(
              m,
              Enum.at(@month_labels, i),
              assigns.cluster_ids,
              assigns.cluster_names,
              assigns.cluster_colors
            )
        }
      end)

    ref_radii =
      Enum.map([0.25, 0.5, 0.75], fn t ->
        @inner_r + t * (@outer_r - @inner_r)
      end)

    assigns =
      assign(assigns,
        month_groups: month_groups,
        ref_radii: ref_radii,
        size: @size,
        center: @center,
        inner_r: @inner_r
      )

    ~H"""
    <Tooltip.container id="season-ring">
      <svg
        viewBox={"0 0 #{@size} #{@size}"}
        preserveAspectRatio="xMidYMid meet"
        style="width: 100%; max-width: 420px; margin: 0 auto; display: block;"
      >
        <g transform={"translate(#{@center},#{@center})"}>
          <%= for r <- @ref_radii do %>
            <circle r={fmt(r)} fill="none" stroke="rgba(255,255,255,0.04)" stroke-width="0.5" />
          <% end %>
          <circle r={@inner_r} fill="none" stroke="rgba(255,255,255,0.08)" stroke-width="0.5" />

          <%= for m <- @month_groups do %>
            <%= if m.total == 0 do %>
              <path
                d={m.empty_path}
                fill="none"
                stroke="rgba(255,255,255,0.05)"
                stroke-width="0.5"
                stroke-dasharray="2,2"
              />
            <% else %>
              <g>
                <%= for arc <- m.arcs do %>
                  <path
                    class={arc.class}
                    data-cluster={arc.cluster}
                    d={arc.d}
                    fill={arc.color}
                    stroke={arc.color}
                  />
                <% end %>
                <path
                  d={m.empty_path}
                  fill="transparent"
                  data-tooltip={m.tooltip}
                />
              </g>
            <% end %>

            <text
              x={fmt(elem(m.label_xy, 0))}
              y={fmt(elem(m.label_xy, 1))}
              text-anchor="middle"
              dominant-baseline="central"
              fill="#666"
              font-size="10px"
              font-weight="600"
            >
              {m.label}
            </text>
          <% end %>
        </g>
      </svg>

      <style>
        .season-arc { fill-opacity: 0.7; stroke-width: 0.5; stroke-opacity: 0.3; transition: fill-opacity 0.2s, stroke-opacity 0.2s; }
        .season-arc.highlight { fill-opacity: 0.85; stroke-opacity: 0.6; }
        .season-arc.dim { fill-opacity: 0.08; stroke-opacity: 0.05; }
      </style>
    </Tooltip.container>
    """
  end

  # --- Arc generation ---

  defp build_month_arcs(month, cluster_ids, cluster_colors, start_angle, end_angle, selected) do
    {arcs, _} =
      Enum.reduce(cluster_ids, {[], 0.0}, fn cid, {acc, cumulative} ->
        count = Map.get(month.counts || %{}, cid, 0)
        proportion = if month.total > 0, do: count / month.total, else: 0

        if proportion <= 0 do
          {acc, cumulative}
        else
          r_inner = @inner_r + cumulative * (@outer_r - @inner_r)
          r_outer = @inner_r + (cumulative + proportion) * (@outer_r - @inner_r)

          arc = %{
            cluster: cid,
            color: Map.get(cluster_colors, cid, "#666"),
            d: annular_path(r_inner, r_outer, start_angle, end_angle),
            class: arc_class(cid, selected)
          }

          {[arc | acc], cumulative + proportion}
        end
      end)

    Enum.reverse(arcs)
  end

  # d3 convention: angle=0 points up, increases clockwise.
  # SVG y-down: point = (r * sin(a), -r * cos(a))
  defp annular_path(r_inner, r_outer, start_angle, end_angle) do
    {ix0, iy0} = polar(r_inner, start_angle)
    {ix1, iy1} = polar(r_inner, end_angle)
    {ox0, oy0} = polar(r_outer, start_angle)
    {ox1, oy1} = polar(r_outer, end_angle)

    sweep_delta = end_angle - start_angle
    large_arc = if sweep_delta > :math.pi(), do: "1", else: "0"

    # Outer arc forward (sweep=1, clockwise in d3's frame), inner arc back (sweep=0)
    "M#{fmt(ox0)},#{fmt(oy0)} " <>
      "A#{fmt(r_outer)},#{fmt(r_outer)} 0 #{large_arc} 1 #{fmt(ox1)},#{fmt(oy1)} " <>
      "L#{fmt(ix1)},#{fmt(iy1)} " <>
      "A#{fmt(r_inner)},#{fmt(r_inner)} 0 #{large_arc} 0 #{fmt(ix0)},#{fmt(iy0)} Z"
  end

  defp polar(r, angle), do: {r * :math.sin(angle), -r * :math.cos(angle)}

  defp label_point(start_angle, end_angle) do
    mid = (start_angle + end_angle) / 2
    polar(@label_r, mid)
  end

  defp arc_class(_cluster, nil), do: "season-arc"
  defp arc_class(cluster, cluster), do: "season-arc highlight"
  defp arc_class(_cluster, _selected), do: "season-arc dim"

  # --- Tooltip HTML (embedded as a data attribute; HoverTooltip reads it on hover) ---

  defp tooltip_html(month, label, cluster_ids, cluster_names, cluster_colors) do
    sorted =
      cluster_ids
      |> Enum.map(fn cid ->
        count = Map.get(month.counts || %{}, cid, 0)

        %{
          id: cid,
          count: count,
          name: Map.get(cluster_names, cid, cid),
          color: Map.get(cluster_colors, cid, "#888")
        }
      end)
      |> Enum.filter(&(&1.count > 0))
      |> Enum.sort_by(& &1.count, :desc)

    rows =
      Enum.map_join(sorted, "", fn d ->
        pct = round(d.count / max(month.total, 1) * 100)

        ~s|<span style="display:inline-flex;align-items:center;gap:3px">| <>
          ~s|<span style="width:6px;height:6px;border-radius:50%;background:#{d.color};display:inline-block"></span>| <>
          "#{d.name}</span>" <>
          ~s|<span style="color:#888;text-align:right">#{d.count}d</span>| <>
          "<strong>#{pct}%</strong>"
      end)

    ~s|<strong style="font-size:13px">#{label}</strong>| <>
      ~s|<div style="color:#666;font-size:10px;margin-bottom:6px">#{month.total} days across all years</div>| <>
      ~s|<div style="display:grid;grid-template-columns:auto auto auto;gap:1px 10px">#{rows}</div>|
  end

  defp fmt(n) when is_integer(n), do: Integer.to_string(n)
  defp fmt(n) when is_float(n), do: :erlang.float_to_binary(n, [:compact, decimals: 2])
end
