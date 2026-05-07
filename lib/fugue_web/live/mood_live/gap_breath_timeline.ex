defmodule FugueWeb.MoodLive.GapBreathTimeline do
  @moduledoc """
  Breath-shaped visualization of silent stretches (data gaps). Width = duration,
  vertical half-height = model confidence, fill = dominant imputed state.
  Replaces the former `GapBreathTimeline` JS hook.
  """

  use Phoenix.Component

  alias FugueWeb.MoodLive.SvgMath

  @svg_width 900
  @height 170
  @m_top 18
  @m_right 14
  @m_bottom 22
  @m_left 14
  @inner_w @svg_width - @m_left - @m_right
  @inner_h @height - @m_top - @m_bottom
  @mid_y @inner_h / 2
  @min_blob_width 4
  @max_half_height 46
  @min_half_height 1.2

  attr :transitions, :list, default: []
  attr :imputed_memberships, :map, default: %{}
  attr :date_range, :any, default: nil
  attr :cluster_colors, :map, default: %{}
  attr :cluster_names, :map, default: %{}

  def timeline(assigns) do
    case assigns.date_range do
      nil ->
        assign(assigns, :empty?, true) |> render_empty()

      %{start: start_str, end: end_str} ->
        min_d = Date.from_iso8601!(start_str)
        max_d = Date.from_iso8601!(end_str)
        span = max(Date.diff(max_d, min_d), 1)

        x_fn = fn date_str ->
          Date.diff(Date.from_iso8601!(date_str), min_d) / span * @inner_w
        end

        blobs =
          assigns.transitions
          |> Enum.map(fn t ->
            build_blob(
              t,
              assigns.imputed_memberships,
              assigns.cluster_colors,
              assigns.cluster_names,
              x_fn
            )
          end)
          |> Enum.reject(&is_nil/1)

        year_ticks =
          for y <- min_d.year..max_d.year,
              jan1 = Date.new!(y, 1, 1),
              Date.compare(jan1, min_d) != :lt and Date.compare(jan1, max_d) != :gt do
            %{x: x_fn.(Date.to_iso8601(jan1)), label: Integer.to_string(y)}
          end

        assigns =
          assign(assigns,
            blobs: blobs,
            year_ticks: year_ticks,
            empty?: blobs == [],
            svg_width: @svg_width,
            svg_height: @height,
            inner_w: @inner_w,
            inner_h: @inner_h,
            mid_y: @mid_y,
            g_transform: "translate(#{@m_left},#{@m_top})",
            axis_transform: "translate(0,#{@inner_h + 2})"
          )

        render_full(assigns)
    end
  end

  defp render_empty(assigns) do
    ~H"""
    <div id="gap-breath-timeline"></div>
    """
  end

  defp render_full(assigns) do
    ~H"""
    <div id="gap-breath-timeline" phx-hook="HoverTooltip" style="position: relative;">
      <svg
        viewBox={"0 0 #{@svg_width} #{@svg_height}"}
        preserveAspectRatio="xMidYMid meet"
        style="display: block; width: 100%;"
      >
        <g transform={@g_transform}>
          <line
            x1="0"
            x2={@inner_w}
            y1={SvgMath.fmt(@mid_y)}
            y2={SvgMath.fmt(@mid_y)}
            stroke="rgba(255,255,255,0.08)"
            stroke-width="1"
          />

          <g transform={@axis_transform}>
            <%= for t <- @year_ticks do %>
              <text
                x={SvgMath.fmt(t.x)}
                y="12"
                text-anchor="middle"
                fill="#666"
                font-size="10px"
              >
                {t.label}
              </text>
            <% end %>
          </g>

          <%= if @empty? do %>
            <text
              x={SvgMath.fmt(@inner_w / 2)}
              y={SvgMath.fmt(@mid_y)}
              text-anchor="middle"
              fill="#666"
              font-size="11px"
            >
              no gaps in range
            </text>
          <% else %>
            <%= for blob <- @blobs do %>
              <path
                class="breath"
                d={blob.d}
                fill={blob.color}
                fill-opacity="0.72"
                stroke={blob.color}
                stroke-opacity="0.9"
                stroke-width="0.6"
                style="cursor: pointer;"
                data-tooltip={blob.tooltip}
                phx-click="gap_selected"
                phx-value-start={blob.start_str}
                phx-value-length={blob.length}
              />
            <% end %>
          <% end %>
        </g>
      </svg>

      <style>
        .breath { transition: fill-opacity 0.15s; }
        .breath:hover { fill-opacity: 1 !important; }
      </style>
    </div>
    """
  end

  # --- Blob construction ---

  defp build_blob(transition, imputed, cluster_colors, cluster_names, x_fn) do
    gap = transition["gap"] || %{}
    start_str = gap["start"]
    length = gap["length"]

    with true <- is_binary(start_str) and is_integer(length) and length > 0,
         {:ok, start_date} <- Date.from_iso8601(start_str) do
      {samples, totals, peak_half} = walk_gap(start_date, length, imputed, transition)

      dominant = totals |> Enum.max_by(fn {_, v} -> v end, fn -> {nil, 0} end) |> elem(0)
      color = (dominant && Map.get(cluster_colors, dominant)) || "#888"
      cluster_name = (dominant && Map.get(cluster_names, dominant, dominant)) || "--"

      end_date = Date.add(start_date, max(length - 1, 0))
      end_str = Date.to_iso8601(end_date)
      start_x = x_fn.(start_str)
      end_x = x_fn.(end_str)
      width_px = end_x - start_x

      d =
        if length(samples) >= 2 and width_px >= @min_blob_width do
          upper = Enum.map(samples, fn s -> {x_fn.(s.date), @mid_y - s.half} end)
          lower = Enum.map(samples, fn s -> {x_fn.(s.date), @mid_y + s.half} end)
          area_path(upper, lower)
        else
          cx = start_x
          r = max(@min_blob_width / 2, width_px / 2)
          top = @mid_y - peak_half
          bot = @mid_y + peak_half

          "M#{SvgMath.fmt(cx - r)} #{SvgMath.fmt(top)} " <>
            "L#{SvgMath.fmt(cx + r)} #{SvgMath.fmt(top)} " <>
            "L#{SvgMath.fmt(cx + r)} #{SvgMath.fmt(bot)} " <>
            "L#{SvgMath.fmt(cx - r)} #{SvgMath.fmt(bot)} Z"
        end

      plural = if length == 1, do: "day", else: "days"

      tooltip =
        ~s|<strong>#{start_str}</strong> · #{length} #{plural}<div style="color:#{color}">#{cluster_name}</div>|

      %{
        start_str: start_str,
        length: length,
        color: color,
        d: d,
        tooltip: tooltip
      }
    else
      _ -> nil
    end
  end

  defp walk_gap(start_date, length, imputed, transition) do
    Enum.reduce(0..(length - 1), {[], %{}, @min_half_height}, fn i,
                                                                 {samples_acc, totals_acc,
                                                                  peak_acc} ->
      day = Date.add(start_date, i)
      key = Date.to_iso8601(day)
      mems = Map.get(imputed || %{}, key) || Map.get(transition, "before", %{}) || %{}
      {cluster, strength} = dominant_of(mems)

      new_totals =
        if cluster,
          do: Map.update(totals_acc, cluster, strength, &(&1 + strength)),
          else: totals_acc

      half = max(@min_half_height, strength * @max_half_height)
      new_peak = max(peak_acc, half)
      sample = %{date: key, half: half, strength: strength, cluster: cluster}
      {[sample | samples_acc], new_totals, new_peak}
    end)
    |> then(fn {samples, totals, peak} -> {Enum.reverse(samples), totals, peak} end)
  end

  defp dominant_of(mems) when is_map(mems) and map_size(mems) > 0 do
    Enum.reduce(mems, {nil, 0}, fn {k, v}, {best_k, best_v} ->
      if is_number(v) and v > best_v, do: {k, v}, else: {best_k, best_v}
    end)
  end

  defp dominant_of(_), do: {nil, 0}

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
end
