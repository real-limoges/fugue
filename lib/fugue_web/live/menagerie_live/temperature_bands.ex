defmodule FugueWeb.MenagerieLive.TemperatureBands do
  @moduledoc """
  Server-rendered membership-function shapes + stacked-area band chart for the
  fuzzy temperature page. Replaces the former `TemperatureBands` JS hook.

  A tiny `BandsHover` hook handles crosshair + tooltip positioning on the
  bands panel; everything else is computed in Elixir.
  """

  use Phoenix.Component

  alias FugueWeb.MoodLive.SvgMath

  @width 820
  @shapes_h 130
  @bands_h 260
  @m_top 18
  @m_right 14
  @m_bottom 26
  @m_left 44
  @inner_w @width - @m_left - @m_right
  @shapes_inner_h @shapes_h - @m_top - @m_bottom
  @bands_inner_h @bands_h - @m_top - @m_bottom

  attr :series, :list, default: []
  attr :mfs, :list, default: []
  attr :shapes, :list, default: []
  attr :bounds, :list, default: [0.0, 48.0]

  def bands(assigns) do
    [lo, hi] = assigns.bounds
    temp_span = max(hi - lo, 1.0e-9)
    temp_x = fn t -> (t - lo) / temp_span * @inner_w end
    temp_y = fn v -> @shapes_inner_h - v * @shapes_inner_h end

    shapes_rendered =
      Enum.map(assigns.shapes, fn shape ->
        samples = shape.samples
        pts = Enum.map(samples, fn [t, v] -> {temp_x.(t), temp_y.(v)} end)

        line_d =
          case pts do
            [] ->
              ""

            [{x, y} | rest] ->
              "M#{SvgMath.fmt(x)},#{SvgMath.fmt(y)}" <>
                Enum.map_join(rest, "", fn {x, y} -> "L#{SvgMath.fmt(x)},#{SvgMath.fmt(y)}" end)
          end

        area_d =
          case pts do
            [] ->
              ""

            [{x0, _y0} | _] = list ->
              {xn, _} = List.last(list)
              base_y = SvgMath.fmt(temp_y.(0))

              "M#{SvgMath.fmt(x0)},#{base_y}L" <>
                Enum.map_join(list, "L", fn {x, y} -> "#{SvgMath.fmt(x)},#{SvgMath.fmt(y)}" end) <>
                "L#{SvgMath.fmt(xn)},#{base_y}Z"
          end

        %{
          name: shape.name,
          color: shape.color,
          line_d: line_d,
          area_d: area_d,
          label_x: temp_x.(shape.peak),
          label_y: temp_y.(1) - 5
        }
      end)

    x_temp_ticks =
      for t <- 0..8,
          v = lo + t / 8 * temp_span,
          do: %{x: temp_x.(v), label: "#{round(v)}°"}

    # --- Bands panel ---
    series = assigns.series
    mf_names = Enum.map(assigns.mfs, & &1.name)
    mf_colors = Map.new(assigns.mfs, &{&1.name, &1.color})

    {layers, year_lines, date_ticks, band_labels, series_json} =
      if series == [] do
        {[], [], [], [], "[]"}
      else
        dates = Enum.map(series, & &1.date)
        {min_d, max_d} = date_range(dates)
        span_days = max(Date.diff(max_d, min_d), 1)

        band_x = fn d -> Date.diff(Date.from_iso8601!(d), min_d) / span_days * @inner_w end
        band_y = fn v -> @bands_inner_h - v * @bands_inner_h end

        stacked =
          Enum.map(series, fn point ->
            {slices, _} =
              Enum.reduce(mf_names, {[], 0.0}, fn name, {acc, accumulated} ->
                val = Map.get(point.memberships, name, 0) * 1.0
                new_top = accumulated + val
                {[{name, accumulated, new_top} | acc], new_top}
              end)

            %{
              x: band_x.(point.date),
              slices: Enum.reverse(slices),
              date: point.date,
              memberships: point.memberships
            }
          end)

        layers =
          Enum.map(mf_names, fn name ->
            upper =
              Enum.map(stacked, fn p ->
                {_, _, y1} = List.keyfind(p.slices, name, 0)
                {p.x, band_y.(y1)}
              end)

            lower =
              Enum.map(stacked, fn p ->
                {_, y0, _} = List.keyfind(p.slices, name, 0)
                {p.x, band_y.(y0)}
              end)

            %{name: name, color: Map.get(mf_colors, name, "#666"), d: area_path(upper, lower)}
          end)

        year_lines =
          for y <- min_d.year..(max_d.year + 1),
              jan1 = Date.new!(y, 1, 1),
              Date.compare(jan1, min_d) != :lt and Date.compare(jan1, max_d) != :gt do
            %{x: band_x.(Date.to_iso8601(jan1))}
          end

        date_ticks =
          for y <- min_d.year..max_d.year,
              jan1 = Date.new!(y, 1, 1),
              Date.compare(jan1, min_d) != :lt and Date.compare(jan1, max_d) != :gt do
            %{x: band_x.(Date.to_iso8601(jan1)), label: Integer.to_string(y)}
          end

        band_labels =
          case List.last(stacked) do
            nil ->
              []

            last ->
              Enum.map(last.slices, fn {name, y0, y1} ->
                height = abs(band_y.(y1) - band_y.(y0))

                %{
                  name: name,
                  y: band_y.((y0 + y1) / 2) + 3,
                  color: Map.get(mf_colors, name, "#666"),
                  visible?: height >= 11
                }
              end)
          end

        # Per-day data for the hover tooltip, one row per day.
        # Shipped as JSON in a data attr; tiny JS hook bisects by x position.
        series_json =
          stacked
          |> Enum.map(fn p -> %{x: p.x, date: p.date, mems: p.memberships} end)
          |> Jason.encode!()

        {layers, year_lines, date_ticks, band_labels, series_json}
      end

    y_ticks =
      for t <- 0..4,
          v = t / 4,
          do: %{y: @bands_inner_h - v * @bands_inner_h, label: "#{round(v * 100)}%"}

    mfs_json = Jason.encode!(Enum.map(assigns.mfs, &Map.take(&1, [:name, :color])))

    assigns =
      assign(assigns,
        shapes_rendered: shapes_rendered,
        x_temp_ticks: x_temp_ticks,
        layers: layers,
        year_lines: year_lines,
        date_ticks: date_ticks,
        band_labels: band_labels,
        y_ticks: y_ticks,
        series_json: series_json,
        mfs_json: mfs_json,
        svg_width: @width,
        shapes_height: @shapes_h,
        bands_height: @bands_h,
        inner_w: @inner_w,
        shapes_inner_h: @shapes_inner_h,
        bands_inner_h: @bands_inner_h,
        g_transform: "translate(#{@m_left},#{@m_top})",
        shapes_axis_transform: "translate(0,#{@shapes_inner_h})",
        bands_axis_transform: "translate(0,#{@bands_inner_h})",
        m_left: @m_left,
        m_top: @m_top
      )

    ~H"""
    <div id="temperature-bands" phx-hook="BandsHover" style="position: relative;">
      <div style="display: flex; flex-direction: column; gap: 14px;">
        <div>
          <div class="text-[10px] uppercase tracking-[0.2em] text-gray-500 mb-1">
            membership functions · drag sliders to reshape
          </div>
          <svg
            viewBox={"0 0 #{@svg_width} #{@shapes_height}"}
            preserveAspectRatio="xMidYMid meet"
            style="width: 100%;"
          >
            <g transform={@g_transform}>
              <line x1="0" x2={@inner_w} y1={@shapes_inner_h} y2={@shapes_inner_h} stroke="#374151" />

              <%= for shape <- @shapes_rendered do %>
                <path d={shape.area_d} fill={shape.color} fill-opacity="0.18" />
                <path d={shape.line_d} fill="none" stroke={shape.color} stroke-width="1.75" />
                <text
                  x={SvgMath.fmt(shape.label_x)}
                  y={SvgMath.fmt(shape.label_y)}
                  fill={shape.color}
                  font-size="11"
                  font-weight="600"
                  text-anchor="middle"
                >
                  {shape.name}
                </text>
              <% end %>

              <g transform={@shapes_axis_transform}>
                <line x1="0" x2={@inner_w} y1="0" y2="0" stroke="#374151" />
                <%= for t <- @x_temp_ticks do %>
                  <line x1={SvgMath.fmt(t.x)} x2={SvgMath.fmt(t.x)} y1="0" y2="3" stroke="#374151" />
                  <text x={SvgMath.fmt(t.x)} y="14" text-anchor="middle" fill="#9ca3af" font-size="10">
                    {t.label}
                  </text>
                <% end %>
              </g>
            </g>
          </svg>
        </div>

        <div style="position: relative;">
          <div class="text-[10px] uppercase tracking-[0.2em] text-gray-500 mb-1">
            fuzzy memberships over time · hover for breakdown
          </div>
          <svg
            id="bands-svg"
            viewBox={"0 0 #{@svg_width} #{@bands_height}"}
            preserveAspectRatio="xMidYMid meet"
            style="width: 100%; display: block;"
            data-series={@series_json}
            data-mfs={@mfs_json}
            data-inner-w={@inner_w}
            data-inner-h={@bands_inner_h}
            data-m-left={@m_left}
            data-m-top={@m_top}
          >
            <g transform={@g_transform}>
              <%= for layer <- @layers do %>
                <path class="band" d={layer.d} fill={layer.color} opacity="0.92" />
              <% end %>

              <g class="year-ticks">
                <%= for y <- @year_lines do %>
                  <line
                    x1={SvgMath.fmt(y.x)}
                    x2={SvgMath.fmt(y.x)}
                    y1="0"
                    y2={@bands_inner_h}
                    stroke="#ffffff"
                    stroke-opacity="0.14"
                    stroke-dasharray="2,3"
                  />
                <% end %>
              </g>

              <g transform={@bands_axis_transform}>
                <line x1="0" x2={@inner_w} y1="0" y2="0" stroke="#374151" />
                <%= for t <- @date_ticks do %>
                  <line x1={SvgMath.fmt(t.x)} x2={SvgMath.fmt(t.x)} y1="0" y2="3" stroke="#374151" />
                  <text x={SvgMath.fmt(t.x)} y="16" text-anchor="middle" fill="#9ca3af" font-size="10">
                    {t.label}
                  </text>
                <% end %>
              </g>

              <g>
                <line x1="0" x2="0" y1="0" y2={@bands_inner_h} stroke="#374151" />
                <%= for t <- @y_ticks do %>
                  <line x1="-3" x2="0" y1={SvgMath.fmt(t.y)} y2={SvgMath.fmt(t.y)} stroke="#374151" />
                  <text
                    x="-6"
                    y={SvgMath.fmt(t.y + 3)}
                    text-anchor="end"
                    fill="#9ca3af"
                    font-size="10"
                  >
                    {t.label}
                  </text>
                <% end %>
              </g>

              <%= for label <- @band_labels, label.visible? do %>
                <text
                  x={@inner_w - 6}
                  y={SvgMath.fmt(label.y)}
                  font-size="10"
                  font-weight="700"
                  text-anchor="end"
                  paint-order="stroke"
                  stroke="#0f172a"
                  stroke-width="3"
                  stroke-linejoin="round"
                  fill={label.color}
                >
                  {label.name}
                </text>
              <% end %>

              <line
                class="bands-crosshair"
                y1="0"
                y2={@bands_inner_h}
                stroke="#f8fafc"
                stroke-width="1"
                opacity="0"
              />
            </g>
          </svg>
        </div>
      </div>
    </div>
    """
  end

  defp area_path(upper, lower) do
    upper_path = SvgMath.basis_path(upper)
    lower_path = SvgMath.basis_path(Enum.reverse(lower))

    lower_continued =
      case lower_path do
        "M" <> rest -> "L" <> rest
        "" -> ""
        other -> other
      end

    upper_path <> lower_continued <> "Z"
  end

  defp date_range([first | _] = dates) do
    parsed = Enum.map(dates, &Date.from_iso8601!/1)
    {Enum.min(parsed, Date), Enum.max(parsed, Date)}
  rescue
    _ -> {Date.from_iso8601!(first), Date.from_iso8601!(first)}
  end
end
