defmodule FugueWeb.MoodLive.CalendarGrid do
  @moduledoc """
  Server-rendered calendar heatmap SVG for /mood.

  Replaces the former `CalendarHeatmap` JS hook (d3-based). Cell positions,
  fills, strokes, and strong-cluster membership are precomputed in Elixir; the
  component emits a single SVG whose per-cell classes reflect highlight /
  gap / cluster-isolate state from assigns. A tiny `CalendarTooltip` JS hook
  handles hover positioning only.
  """

  use Phoenix.Component

  @cell_size 13
  @cell_gap 2
  @cell_step @cell_size + @cell_gap
  @year_padding 24
  @left_margin 30
  @top_margin 20

  attr :days, :list, default: []
  attr :cluster_colors, :map, default: %{}
  attr :cluster_names, :map, default: %{}
  attr :transition_dates, :list, default: []
  attr :highlighted_dates, :list, default: []
  attr :selected_gap, :any, default: nil
  attr :selected_cluster, :any, default: nil

  def grid(assigns) do
    highlighted_set = MapSet.new(assigns.highlighted_dates || [])
    transition_set = MapSet.new(assigns.transition_dates || [])
    gap_set = gap_dates_set(assigns.selected_gap)

    cells =
      Enum.map(assigns.days, fn day ->
        build_cell(day, assigns.cluster_colors, assigns.cluster_names,
          transition_set: transition_set,
          highlighted_set: highlighted_set,
          gap_set: gap_set,
          selected_cluster: assigns.selected_cluster
        )
      end)

    years = cells |> Enum.map(& &1.year) |> Enum.uniq() |> Enum.sort()

    year_groups =
      Enum.with_index(years)
      |> Enum.map(fn {year, yi} ->
        y_offset = @top_margin + yi * (7 * @cell_step + @year_padding)

        labels =
          if yi == 0 do
            [nil, "Mon", nil, "Wed", nil, "Fri", nil]
            |> Enum.with_index()
            |> Enum.reject(fn {l, _} -> is_nil(l) end)
            |> Enum.map(fn {l, i} ->
              %{label: l, y: y_offset + i * @cell_step + @cell_size - 1}
            end)
          else
            []
          end

        %{
          year: year,
          y_offset: y_offset,
          label_y: y_offset + 3.5 * @cell_step,
          g_transform: "translate(#{@left_margin}, #{y_offset})",
          cells: Enum.filter(cells, &(&1.year == year)),
          weekday_labels: labels
        }
      end)

    svg_classes =
      [
        "calendar-svg",
        MapSet.size(highlighted_set) > 0 && "has-highlight",
        assigns.selected_gap && "has-gap-highlight",
        assigns.selected_cluster && "has-cluster-isolate"
      ]
      |> Enum.filter(& &1)
      |> Enum.join(" ")

    assigns =
      assign(assigns,
        year_groups: year_groups,
        svg_width: @left_margin + 53 * @cell_step + 20,
        svg_height: @top_margin + length(years) * (7 * @cell_step + @year_padding),
        svg_classes: svg_classes,
        cell_size: @cell_size,
        weekday_label_x: @left_margin - 4
      )

    ~H"""
    <div id="calendar-heatmap" phx-hook="CalendarTooltip" style="position: relative;">
      <svg width={@svg_width} height={@svg_height} class={@svg_classes}>
        <defs>
          <pattern
            id="gap-hatch"
            width="4"
            height="4"
            patternUnits="userSpaceOnUse"
            patternTransform="rotate(45)"
          >
            <line x1="0" y1="0" x2="0" y2="4" stroke="#555" stroke-width="1" />
          </pattern>
        </defs>

        <%= for group <- @year_groups do %>
          <text
            x="0"
            y={group.label_y}
            text-anchor="start"
            fill="#888"
            font-size="11px"
            font-weight="bold"
          >
            {group.year}
          </text>

          <%= for wl <- group.weekday_labels do %>
            <text
              x={@weekday_label_x}
              y={wl.y}
              text-anchor="end"
              fill="#666"
              font-size="9px"
            >
              {wl.label}
            </text>
          <% end %>

          <g transform={group.g_transform}>
            <%= for cell <- group.cells do %>
              <rect
                class={cell.class}
                data-date={cell.date}
                data-tooltip={cell.tooltip_html}
                width={@cell_size}
                height={@cell_size}
                rx="2"
                x={cell.x}
                y={cell.y}
                fill={cell.fill}
                stroke={cell.stroke}
                stroke-width={cell.stroke_width}
                stroke-dasharray={cell.stroke_dasharray}
                style={"cursor: #{if cell.is_gap, do: "default", else: "pointer"};"}
                phx-click={!cell.is_gap && "day_selected"}
                phx-value-date={!cell.is_gap && cell.date}
              />
            <% end %>
          </g>
        <% end %>
      </svg>

      <style>
        .calendar-svg.has-highlight .day-cell { opacity: 0.15; }
        .calendar-svg.has-highlight .day-cell.highlighted { opacity: 1; }
        .calendar-svg.has-gap-highlight .day-cell { opacity: 0.15; }
        .calendar-svg.has-gap-highlight .day-cell.gap-highlighted {
          opacity: 1;
          stroke: #f39c12;
          stroke-width: 2;
        }
        .calendar-svg.has-cluster-isolate .day-cell { opacity: 0.08; }
        .calendar-svg.has-cluster-isolate .day-cell.matches-cluster { opacity: 1; }
      </style>
    </div>
    """
  end

  # --- Cell construction ---

  defp build_cell(day, cluster_colors, cluster_names, opts) do
    transition_set = Keyword.fetch!(opts, :transition_set)
    highlighted_set = Keyword.fetch!(opts, :highlighted_set)
    gap_set = Keyword.fetch!(opts, :gap_set)
    selected_cluster = Keyword.fetch!(opts, :selected_cluster)

    {top_cluster, top_weight} = top_membership(day.memberships)
    strong_clusters = strong_cluster_ids(day.memberships)
    {x, y, year} = cell_position(day.date)

    class =
      [
        "day-cell",
        day.is_gap && "is-gap",
        MapSet.member?(transition_set, day.date) && "is-transition",
        MapSet.member?(highlighted_set, day.date) && "highlighted",
        MapSet.member?(gap_set, day.date) && "gap-highlighted",
        selected_cluster && selected_cluster in strong_clusters && "matches-cluster"
      ]
      |> Enum.filter(& &1)
      |> Enum.join(" ")

    %{
      date: day.date,
      is_gap: day.is_gap,
      year: year,
      x: x,
      y: y,
      class: class,
      fill: cell_fill(day, top_cluster, top_weight, cluster_colors),
      stroke: cell_stroke(day, top_cluster, top_weight, cluster_colors, transition_set),
      stroke_width: cell_stroke_width(day, top_weight, transition_set),
      stroke_dasharray: if(day.is_gap, do: "2,1", else: "none"),
      tooltip_html: build_tooltip_html(day, cluster_colors, cluster_names)
    }
  end

  defp cell_position(date_str) do
    date = Date.from_iso8601!(date_str)
    year = date.year
    jan1 = Date.new!(year, 1, 1)
    jan1_dow = js_dow(jan1)
    day_offset = Date.diff(date, jan1)
    week_num = div(day_offset + jan1_dow, 7)
    x = week_num * @cell_step
    y = js_dow(date) * @cell_step
    {x, y, to_string(year)}
  end

  # JavaScript's Date.getDay: Sunday=0..Saturday=6. Elixir's Date.day_of_week: Monday=1..Sunday=7.
  defp js_dow(date) do
    case Date.day_of_week(date) do
      7 -> 0
      n -> n
    end
  end

  defp cell_fill(%{is_gap: true}, top_cluster, top_weight, colors)
       when not is_nil(top_cluster) do
    dominant_color(top_cluster, top_weight, colors, 0.3)
  end

  defp cell_fill(%{is_gap: true}, _, _, _), do: "url(#gap-hatch)"

  defp cell_fill(_day, nil, _weight, _colors), do: "#2a2a2a"

  defp cell_fill(_day, top_cluster, top_weight, colors),
    do: dominant_color(top_cluster, top_weight, colors, 1.0)

  defp dominant_color(cluster, weight, colors, base_opacity) do
    {r, g, b} = hex_to_rgb(Map.get(colors, cluster) || "#666")
    alpha = base_opacity * (0.12 + 0.88 * :math.pow(weight, 1.5))
    "rgba(#{r}, #{g}, #{b}, #{Float.round(alpha, 3)})"
  end

  defp cell_stroke(day, top_cluster, top_weight, colors, transition_set) do
    cond do
      MapSet.member?(transition_set, day.date) -> "#fff"
      day.is_gap -> "#555"
      is_nil(top_cluster) or top_weight < 0.5 -> "none"
      true -> Map.get(colors, top_cluster, "none")
    end
  end

  defp cell_stroke_width(day, top_weight, transition_set) do
    cond do
      MapSet.member?(transition_set, day.date) -> "2"
      day.is_gap -> "0.5"
      top_weight >= 0.65 -> "1.5"
      top_weight >= 0.5 -> "0.75"
      true -> "0"
    end
  end

  defp top_membership(mems) when is_map(mems) and map_size(mems) > 0 do
    Enum.max_by(mems, fn {_k, v} -> v end)
  end

  defp top_membership(_), do: {nil, 0}

  defp strong_cluster_ids(mems) when is_map(mems) do
    mems |> Enum.filter(fn {_k, v} -> v >= 0.3 end) |> Enum.map(fn {k, _} -> k end)
  end

  defp strong_cluster_ids(_), do: []

  defp hex_to_rgb("#" <> <<r::binary-size(2), g::binary-size(2), b::binary-size(2)>>) do
    {String.to_integer(r, 16), String.to_integer(g, 16), String.to_integer(b, 16)}
  end

  defp hex_to_rgb(_), do: {102, 102, 102}

  # --- Gap date range ---

  defp gap_dates_set(nil), do: MapSet.new()

  defp gap_dates_set(%{"start" => start, "length" => length}) do
    len = if is_binary(length), do: String.to_integer(length), else: length
    start_date = Date.from_iso8601!(start)

    0..(len - 1)
    |> Enum.map(&(Date.add(start_date, &1) |> Date.to_iso8601()))
    |> MapSet.new()
  end

  defp gap_dates_set(_), do: MapSet.new()

  # --- Tooltip HTML ---
  #
  # Pre-rendered server-side so the JS hook only has to position + show/hide.
  # Output is a plain HTML string assigned to `data-tooltip` on each cell.

  defp build_tooltip_html(day, cluster_colors, cluster_names) do
    IO.iodata_to_binary([
      "<strong style=\"font-size: 13px\">",
      html_escape(day.date),
      "</strong>",
      gap_tag(day.is_gap),
      dimensions_block(day.dimensions),
      memberships_block(day.memberships, cluster_colors, cluster_names)
    ])
  end

  defp gap_tag(true),
    do: "<br><span style=\"color: #666; font-style: italic\">gap day</span>"

  defp gap_tag(_), do: ""

  defp dimensions_block(nil), do: ""
  defp dimensions_block(dims) when map_size(dims) == 0, do: ""

  defp dimensions_block(dims) do
    rows =
      Enum.map_join(dims, "", fn {k, v} ->
        "<span style=\"color: #888\">" <>
          html_escape(to_string(k)) <>
          "</span><strong>" <>
          html_escape(to_string(v)) <>
          "</strong>"
      end)

    "<div style=\"margin-top: 6px; display: grid; grid-template-columns: auto auto; gap: 1px 10px\">" <>
      rows <> "</div>"
  end

  defp memberships_block(nil, _, _), do: ""
  defp memberships_block(mems, _, _) when map_size(mems) == 0, do: ""

  defp memberships_block(mems, cluster_colors, cluster_names) do
    rows =
      mems
      |> Enum.sort_by(fn {_k, v} -> v end, :desc)
      |> Enum.map_join("", fn {id, weight} ->
        membership_row(
          Map.get(cluster_names, id, id),
          Map.get(cluster_colors, id, "#888"),
          weight
        )
      end)

    "<div style=\"margin-top: 6px; border-top: 1px solid rgba(255,255,255,0.08); padding-top: 5px\">" <>
      rows <> "</div>"
  end

  defp membership_row(name, color, weight) do
    pct = weight |> Kernel.*(100) |> round() |> Integer.to_string()
    bar_w = weight |> Kernel.*(50) |> round() |> Integer.to_string()
    safe_name = html_escape(to_string(name))
    safe_color = html_escape(to_string(color))

    "<div style=\"display: flex; align-items: center; gap: 5px; margin: 2px 0\">" <>
      "<span style=\"color: #{safe_color}; font-size: 11px; white-space: nowrap\">#{safe_name}</span>" <>
      "<div style=\"flex: 0 0 50px; height: 3px; background: rgba(255,255,255,0.06); border-radius: 2px\">" <>
      "<div style=\"width: #{bar_w}px; height: 3px; background: #{safe_color}; border-radius: 2px\"></div>" <>
      "</div>" <>
      "<span style=\"color: #888; font-size: 10px; white-space: nowrap\">#{pct}%</span>" <>
      "</div>"
  end

  defp html_escape(s), do: s |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
end
