defmodule FugueWeb.MoodLive.StreamGraph do
  @moduledoc """
  Server-rendered stacked-area streamgraph of cluster membership over time.

  Replaces the former `ClusterStream` JS hook (d3.stack + d3.area + d3 axes).
  Stacking, B-spline-to-Bezier smoothing, and axis tick computation all run
  in Elixir. Isolate-cluster and day-focus effects are CSS-class driven on
  the SVG parent.
  """

  use Phoenix.Component

  alias FugueWeb.MoodLive.{DateRange, SvgMath}

  @width 800
  @height 200
  @m_top 10
  @m_right 15
  @m_bottom 24
  @m_left 30
  @inner_w @width - @m_left - @m_right
  @inner_h @height - @m_top - @m_bottom

  attr :series, :list, default: []
  attr :cluster_ids, :list, default: []
  attr :cluster_colors, :map, default: %{}
  attr :cluster_names, :map, default: %{}
  attr :selected_cluster, :any, default: nil
  attr :selected_day, :map, default: nil

  def stream(assigns) do
    cluster_ids = assigns.cluster_ids
    series = assigns.series

    {layers, x_ticks, tether_x, svg_classes} =
      if series == [] or cluster_ids == [] do
        {[], [], nil, "stream-svg"}
      else
        dates = Enum.map(series, & &1.date)
        {min_d, max_d} = DateRange.from_iso_strings(dates)
        span = max(Date.diff(max_d, min_d), 1)

        x_fn = fn date_str ->
          Date.diff(Date.from_iso8601!(date_str), min_d) / span * @inner_w
        end

        layers = build_layers(series, cluster_ids, assigns.cluster_colors, x_fn)
        x_ticks = year_ticks(min_d, max_d, x_fn)

        tether =
          case assigns.selected_day do
            %{date: d} -> x_fn.(d)
            _ -> nil
          end

        classes =
          [
            "stream-svg",
            assigns.selected_cluster && "has-cluster-isolate",
            tether && "has-day-focus"
          ]
          |> Enum.filter(& &1)
          |> Enum.join(" ")

        {layers, x_ticks, tether, classes}
      end

    y_ticks = [
      %{value: 0, y: @inner_h, label: "0%"},
      %{value: 1, y: 0, label: "100%"}
    ]

    legend =
      Enum.map(cluster_ids, fn id ->
        %{
          id: id,
          name: Map.get(assigns.cluster_names, id, id),
          color: Map.get(assigns.cluster_colors, id, "#888")
        }
      end)

    assigns =
      assign(assigns,
        layers: layers,
        x_ticks: x_ticks,
        y_ticks: y_ticks,
        tether_x: tether_x,
        svg_classes: svg_classes,
        legend: legend,
        inner_h: @inner_h,
        inner_w: @inner_w,
        svg_width: @width,
        svg_height: @height,
        g_transform: "translate(#{@m_left},#{@m_top})"
      )

    ~H"""
    <div id="cluster-stream" style="width: 100%;">
      <svg
        viewBox={"0 0 #{@svg_width} #{@svg_height}"}
        preserveAspectRatio="xMidYMid meet"
        class={@svg_classes}
        style="width: 100%;"
      >
        <g transform={@g_transform}>
          <%= for layer <- @layers do %>
            <path
              class={layer_class(layer.cluster, @selected_cluster)}
              data-cluster={layer.cluster}
              d={layer.d}
              fill={layer.color}
              stroke={layer.color}
            />
          <% end %>

          <g class="x-axis" transform={"translate(0,#{@inner_h})"}>
            <line x1="0" y1="0" x2={@inner_w} y2="0" stroke="#444" />
            <%= for t <- @x_ticks do %>
              <line x1={t.x} y1="0" x2={t.x} y2="3" stroke="#444" />
              <text x={t.x} y="14" text-anchor="middle" fill="#666" font-size="10px">
                {t.label}
              </text>
            <% end %>
          </g>

          <g class="y-axis">
            <line x1="0" y1="0" x2="0" y2={@inner_h} stroke="#444" />
            <%= for t <- @y_ticks do %>
              <line x1="-3" y1={t.y} x2="0" y2={t.y} stroke="#444" />
              <text x="-5" y={t.y + 3} text-anchor="end" fill="#666" font-size="9px">
                {t.label}
              </text>
            <% end %>
          </g>

          <%= if @tether_x do %>
            <line
              class="tether-line"
              x1={@tether_x}
              x2={@tether_x}
              y1="0"
              y2={@inner_h}
              stroke="#fff"
              stroke-width="1.5"
              pointer-events="none"
            />
          <% end %>
        </g>
      </svg>

      <div class="stream-legend">
        <%= for item <- @legend do %>
          <span
            class={legend_class(item.id, @selected_cluster)}
            data-cluster={item.id}
            phx-click="cluster_selected"
            phx-value-cluster={item.id}
            style={"color: #{item.color};"}
          >
            <span class="dot" style={"background: #{item.color};"}></span>
            {item.name}
          </span>
        <% end %>
      </div>

      <style>
        .stream-layer { fill-opacity: 0.65; stroke-width: 0.5; stroke-opacity: 0.3; transition: fill-opacity 0.2s, stroke-opacity 0.2s; }
        .stream-layer.dim { fill-opacity: 0.08; stroke-opacity: 0.05; }
        .stream-layer.highlight { fill-opacity: 0.8; stroke-opacity: 0.6; }

        .tether-line { opacity: 0; transition: opacity 220ms; }
        .stream-svg.has-day-focus .tether-line { opacity: 0.9; }

        .stream-legend {
          display: flex; flex-wrap: wrap; gap: 6px 12px;
          justify-content: center; margin-top: 6px;
        }
        .stream-legend-item {
          display: inline-flex; align-items: center; gap: 4px;
          cursor: pointer; font-size: 11px; font-weight: 500;
          transition: opacity 0.2s;
        }
        .stream-legend-item.dim { opacity: 0.25; }
        .stream-legend-item .dot {
          display: inline-block; width: 8px; height: 8px; border-radius: 50%;
        }
      </style>
    </div>
    """
  end

  # --- Stacking + path generation ---

  defp build_layers(series, cluster_ids, cluster_colors, x_fn) do
    stacked =
      Enum.map(series, fn point ->
        {slices, _} =
          Enum.reduce(cluster_ids, {[], 0.0}, fn cid, {acc, accumulated} ->
            val = Map.get(point.memberships || %{}, cid, 0) * 1.0
            new_top = accumulated + val
            {[{cid, accumulated, new_top} | acc], new_top}
          end)

        %{x: x_fn.(point.date), slices: Enum.reverse(slices)}
      end)

    Enum.map(cluster_ids, fn cid ->
      upper =
        Enum.map(stacked, fn p ->
          {_, _, y1} = List.keyfind(p.slices, cid, 0)
          {p.x, y_to_px(y1)}
        end)

      lower =
        Enum.map(stacked, fn p ->
          {_, y0, _} = List.keyfind(p.slices, cid, 0)
          {p.x, y_to_px(y0)}
        end)

      %{cluster: cid, d: area_path(upper, lower), color: Map.get(cluster_colors, cid, "#666")}
    end)
  end

  defp y_to_px(y_frac), do: @inner_h - y_frac * @inner_h

  defp area_path(upper, lower) do
    upper_path = SvgMath.basis_path(upper)
    lower_path = SvgMath.basis_path(Enum.reverse(lower))
    # Replace the leading "M" of the lower segment with "L" to continue the subpath.
    lower_continued =
      case lower_path do
        "M" <> rest -> "L" <> rest
        "" -> ""
        other -> other
      end

    upper_path <> lower_continued <> "Z"
  end

  # --- Axes ---

  defp year_ticks(min_date, max_date, x_fn) do
    for year <- min_date.year..max_date.year,
        jan1 = Date.new!(year, 1, 1),
        Date.compare(jan1, min_date) != :lt and Date.compare(jan1, max_date) != :gt do
      %{x: x_fn.(Date.to_iso8601(jan1)), label: Integer.to_string(year)}
    end
  end

  defp layer_class(_cluster, nil), do: "stream-layer"
  defp layer_class(cluster, cluster), do: "stream-layer highlight"
  defp layer_class(_cluster, _selected), do: "stream-layer dim"

  defp legend_class(_cluster, nil), do: "stream-legend-item"
  defp legend_class(cluster, cluster), do: "stream-legend-item"
  defp legend_class(_cluster, _selected), do: "stream-legend-item dim"
end
