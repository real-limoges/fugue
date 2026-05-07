defmodule FugueWeb.MoodLive.MoodFlowers do
  @moduledoc """
  Grid of monthly mood-flower radars. Shape encodes raw dimensions; fill
  color encodes the modal cluster for the month. Replaces the former
  `MoodFlowers` JS hook. Petal paths use a closed cardinal spline
  (tension 0.5) to match the original smoothing.
  """

  use Phoenix.Component

  alias FugueWeb.MoodLive.{SvgMath, Tooltip}

  @month_names ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
  @r 40

  attr :flowers, :list, default: []
  attr :dimensions, :list, default: []
  attr :cluster_colors, :map, default: %{}
  attr :cluster_names, :map, default: %{}
  attr :selected_day, :any, default: nil

  def flowers(assigns) do
    by_year =
      assigns.flowers
      |> Enum.group_by(fn f -> String.slice(f.month, 0, 4) end)
      |> Enum.sort_by(fn {y, _} -> y end)

    num_dims = length(assigns.dimensions)
    angle_slice = if num_dims > 0, do: :math.pi() * 2 / num_dims, else: 0

    focus_month =
      case assigns.selected_day do
        %{date: d} when is_binary(d) -> String.slice(d, 0, 7)
        _ -> nil
      end

    rows =
      Enum.map(by_year, fn {year, year_flowers} ->
        by_month = Map.new(year_flowers, &{&1.month, &1})

        cells =
          for mi <- 0..11 do
            month_key = "#{year}-#{String.pad_leading(Integer.to_string(mi + 1), 2, "0")}"

            build_cell(
              Map.get(by_month, month_key),
              month_key,
              mi,
              assigns,
              angle_slice,
              focus_month
            )
          end

        %{year: year, cells: cells}
      end)

    assigns =
      assign(assigns,
        rows: rows,
        month_names: @month_names
      )

    ~H"""
    <Tooltip.container id="mood-flowers">
      <div class="mood-flower-grid">
        <div></div>
        <%= for m <- @month_names do %>
          <div class="mood-flower-month-label">{m}</div>
        <% end %>

        <%= for row <- @rows do %>
          <div class="mood-flower-year-label">{row.year}</div>
          <%= for cell <- row.cells do %>
            <div
              class={cell.class}
              data-month={cell.month}
            >
              <%= if cell.present? do %>
                <svg
                  viewBox="0 0 100 100"
                  preserveAspectRatio="xMidYMid meet"
                  data-tooltip={cell.tooltip}
                  style="width: 100%; height: 100%; display: block; cursor: pointer;"
                >
                  <g transform="translate(50,50)">
                    <circle r="40" fill="none" stroke="rgba(255,255,255,0.06)" stroke-width="0.5" />
                    <circle r="20" fill="none" stroke="rgba(255,255,255,0.04)" stroke-width="0.5" />
                    <path
                      d={cell.petal_d}
                      fill={cell.color}
                      fill-opacity="0.55"
                      stroke={cell.color}
                      stroke-width="1.5"
                      stroke-linejoin="round"
                    />
                  </g>
                </svg>
              <% else %>
                <div class="mood-flower-empty"></div>
              <% end %>
            </div>
          <% end %>
        <% end %>
      </div>

      <style>
        .mood-flower-grid {
          display: grid;
          grid-template-columns: auto repeat(12, 1fr);
          gap: 8px 6px;
          align-items: center;
          margin-top: 4px;
        }
        .mood-flower-month-label {
          text-align: center; color: #666; font-size: 10px;
          font-weight: 600; letter-spacing: 0.5px;
        }
        .mood-flower-year-label {
          color: #888; font-size: 13px; font-weight: 700;
          padding-right: 8px; text-align: right;
        }
        .flower-cell {
          aspect-ratio: 1 / 1; position: relative;
          transition: transform 0.3s ease, filter 0.3s ease;
          transform-origin: center;
        }
        .flower-cell.focused {
          transform: scale(1.35);
          filter: drop-shadow(0 0 6px rgba(255,255,255,0.6));
          z-index: 5;
        }
        .mood-flower-empty {
          width: 100%; height: 100%; border-radius: 50%;
          border: 1px dashed rgba(255,255,255,0.05);
          box-sizing: border-box;
        }
      </style>
    </Tooltip.container>
    """
  end

  defp build_cell(nil, month_key, _mi, _assigns, _angle_slice, focus_month) do
    %{
      month: month_key,
      present?: false,
      class: flower_class(month_key, focus_month),
      petal_d: "",
      color: "#888",
      tooltip: ""
    }
  end

  defp build_cell(flower, month_key, _mi, assigns, angle_slice, focus_month) do
    color =
      if flower.cluster, do: Map.get(assigns.cluster_colors, flower.cluster, "#888"), else: "#888"

    points =
      Enum.with_index(assigns.dimensions)
      |> Enum.map(fn {dim, i} ->
        v = Map.get(flower.values, dim, 0) * 1.0
        angle = angle_slice * i
        r = v * @r
        {:math.sin(angle) * r, -:math.cos(angle) * r}
      end)

    %{
      month: month_key,
      present?: true,
      class: flower_class(month_key, focus_month),
      petal_d: cardinal_closed_path(points, 0.5),
      color: color,
      tooltip: tooltip_html(flower, color, assigns.cluster_names, @month_names)
    }
  end

  defp flower_class(month_key, focus_month) do
    if month_key == focus_month, do: "flower-cell focused", else: "flower-cell"
  end

  # Closed cardinal spline: each segment P_i → P_{i+1} uses neighbors
  # P_{i-1} and P_{i+2} (wrapped) to compute tangents.
  #   c1 = P_i + (P_{i+1} - P_{i-1}) * s
  #   c2 = P_{i+1} - (P_{i+2} - P_i) * s
  # where s = (1 - tension) / 6 by the d3 convention.
  defp cardinal_closed_path([], _), do: ""
  defp cardinal_closed_path([{x, y}], _), do: "M#{SvgMath.fmt(x)},#{SvgMath.fmt(y)}Z"

  defp cardinal_closed_path(points, tension) do
    s = (1 - tension) / 6
    pts = List.to_tuple(points)
    n = tuple_size(pts)
    {x0, y0} = elem(pts, 0)

    segments =
      for i <- 0..(n - 1) do
        {pax, pay} = elem(pts, rem(i - 1 + n, n))
        {pbx, pby} = elem(pts, i)
        {pcx, pcy} = elem(pts, rem(i + 1, n))
        {pdx, pdy} = elem(pts, rem(i + 2, n))

        c1x = pbx + (pcx - pax) * s
        c1y = pby + (pcy - pay) * s
        c2x = pcx - (pdx - pbx) * s
        c2y = pcy - (pdy - pby) * s

        "C#{SvgMath.fmt(c1x)},#{SvgMath.fmt(c1y)} #{SvgMath.fmt(c2x)},#{SvgMath.fmt(c2y)} #{SvgMath.fmt(pcx)},#{SvgMath.fmt(pcy)}"
      end
      |> Enum.join()

    "M#{SvgMath.fmt(x0)},#{SvgMath.fmt(y0)}" <> segments <> "Z"
  end

  defp tooltip_html(flower, color, cluster_names, month_names) do
    cluster_name =
      if flower.cluster, do: Map.get(cluster_names, flower.cluster, flower.cluster), else: "--"

    dims_rows =
      Enum.map_join(flower.raw || %{}, "", fn {k, v} ->
        ~s|<span style="color:#888">#{k}</span><strong>#{:erlang.float_to_binary(v * 1.0, decimals: 1)}</strong>|
      end)

    entries_word = if flower.count == 1, do: "entry", else: "entries"

    ~s|<strong style="font-size:13px">#{month_label(flower.month, month_names)}</strong>| <>
      ~s|<div style="color:#{color};font-size:11px;margin-top:2px;font-weight:600">#{cluster_name}</div>| <>
      ~s|<div style="margin-top:6px;display:grid;grid-template-columns:auto auto;gap:1px 14px">#{dims_rows}</div>| <>
      ~s|<div style="margin-top:4px;color:#666;font-size:10px">#{flower.count} #{entries_word}</div>|
  end

  defp month_label(month_str, month_names) do
    case String.split(month_str, "-") do
      [year, m] ->
        idx = String.to_integer(m) - 1
        "#{Enum.at(month_names, idx)} #{year}"

      _ ->
        month_str
    end
  end
end
