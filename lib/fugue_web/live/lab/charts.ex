defmodule FugueWeb.LabLive.Charts do
  @moduledoc """
  Pure helpers for the small SVG charts used on `/lab` pages: density grids,
  axis frames, and path strings. Lives in Elixir so the LiveView can render
  the chart server-side without a hook.
  """

  @margin %{top: 30, right: 45, bottom: 50, left: 60}

  def margin, do: @margin

  @doc "Inclusive [a, b] grid of n points."
  def linspace(a, b, n) when n > 1 do
    step = (b - a) / (n - 1)
    for i <- 0..(n - 1), do: a + i * step
  end

  @doc """
  Normalized Gamma(α, β) density evaluated at xs. Computed in log-space and
  renormalized over the grid to stay numerically stable for large α.
  """
  def gamma_density(xs, alpha, beta) do
    log_pdf = Enum.map(xs, &gamma_log_pdf(&1, alpha, beta))
    max_lp = log_pdf |> Enum.reject(&is_nil/1) |> Enum.max(fn -> 0.0 end)

    raw =
      Enum.map(log_pdf, fn
        nil -> 0.0
        lp -> :math.exp(lp - max_lp)
      end)

    [x0, x1 | _] = xs
    dx = x1 - x0
    area = Enum.sum(raw) * dx
    if area > 0, do: Enum.map(raw, &(&1 / area)), else: raw
  end

  @doc "Right-tail probability P(X > threshold) by rectangle rule."
  def tail_probability(xs, pdf, threshold) do
    [x0, x1 | _] = xs
    dx = x1 - x0

    p =
      xs
      |> Enum.zip(pdf)
      |> Enum.reduce(0.0, fn {x, y}, acc ->
        if x >= threshold, do: acc + y * dx, else: acc
      end)

    p |> max(0.0) |> min(1.0)
  end

  @doc "SVG path d-string for a polyline through (xs, ys) under scale fns."
  def polyline_path(xs, ys, scale_x, scale_y) do
    xs
    |> Enum.zip(ys)
    |> Enum.with_index()
    |> Enum.map_join(" ", fn {{x, y}, i} ->
      cmd = if i == 0, do: "M", else: "L"
      "#{cmd}#{fmt(scale_x.(x))},#{fmt(scale_y.(y))}"
    end)
  end

  @doc """
  Closed polygon path for the area under (xs, ys) restricted to x >= threshold.
  Returns nil when no points fall in the tail.
  """
  def tail_polygon_path(xs, ys, threshold, scale_x, scale_y) do
    pairs =
      xs
      |> Enum.zip(ys)
      |> Enum.filter(fn {x, _} -> x >= threshold end)

    case pairs do
      [] ->
        nil

      [{first_x, _} | _] ->
        {last_x, _} = List.last(pairs)
        base_y = scale_y.(0)

        body =
          Enum.map_join(pairs, " ", fn {x, y} ->
            "L#{fmt(scale_x.(x))},#{fmt(scale_y.(y))}"
          end)

        "M#{fmt(scale_x.(first_x))},#{fmt(base_y)} #{body} L#{fmt(scale_x.(last_x))},#{fmt(base_y)} Z"
    end
  end

  @doc """
  Returns a frame description: viewport size, scale functions, and tick
  positions in screen space. Templates layer paths/labels on top.
  """
  def axis_frame(opts) do
    width = Keyword.fetch!(opts, :width)
    height = Keyword.get(opts, :height, 420)
    {x_min, x_max} = Keyword.fetch!(opts, :x_range)
    {y_min, y_max} = Keyword.fetch!(opts, :y_range)
    x_ticks = Keyword.get(opts, :x_ticks, [])
    y_ticks = Keyword.get(opts, :y_ticks, [])

    inner_w = width - @margin.left - @margin.right
    inner_h = height - @margin.top - @margin.bottom

    scale_x = fn x -> @margin.left + (x - x_min) / (x_max - x_min) * inner_w end
    scale_y = fn y -> @margin.top + inner_h - (y - y_min) / (y_max - y_min) * inner_h end

    %{
      width: width,
      height: height,
      inner_w: inner_w,
      inner_h: inner_h,
      margin: @margin,
      scale_x: scale_x,
      scale_y: scale_y,
      x_ticks: Enum.map(x_ticks, &%{value: &1, x: scale_x.(&1)}),
      y_ticks: Enum.map(y_ticks, &%{value: &1, y: scale_y.(&1)})
    }
  end

  @doc "Tick label format: integers as-is, floats trimmed of trailing zeros."
  def format_tick(v) when is_integer(v), do: Integer.to_string(v)

  def format_tick(v) when is_float(v) do
    if v == Float.round(v),
      do: Integer.to_string(trunc(v)),
      else: trim_zeros(:erlang.float_to_binary(v, decimals: 2))
  end

  defp trim_zeros(s) do
    s
    |> String.replace(~r/0+$/, "")
    |> String.replace(~r/\.$/, "")
  end

  defp gamma_log_pdf(x, _alpha, _beta) when x <= 0, do: nil
  defp gamma_log_pdf(x, alpha, beta), do: (alpha - 1) * :math.log(x) - beta * x

  defp fmt(v) when is_float(v), do: :erlang.float_to_binary(v, decimals: 2)
  defp fmt(v), do: to_string(v)
end
