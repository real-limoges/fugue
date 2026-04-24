defmodule FugueWeb.MoodLive.SvgMath do
  @moduledoc """
  Shared SVG path generators used across server-rendered mood visualizations.

  Currently exposes `basis_path/1`, a uniform B-spline → cubic Bezier
  conversion matching d3.curveBasis for open lines, and `fmt/1` for compact
  numeric output in SVG attributes.
  """

  @doc """
  Returns an SVG path `d` string drawing a smooth curve through the given
  points using the same uniform B-spline approach as d3.curveBasis.
  """
  def basis_path([]), do: ""
  def basis_path([{x, y}]), do: "M#{fmt(x)},#{fmt(y)}"
  def basis_path([{x0, y0}, {x1, y1}]), do: "M#{fmt(x0)},#{fmt(y0)}L#{fmt(x1)},#{fmt(y1)}"

  def basis_path(points) do
    pts = List.to_tuple(points)
    n = tuple_size(pts)
    {x0, y0} = elem(pts, 0)
    {x1, y1} = elem(pts, 1)

    first =
      "M#{fmt(x0)},#{fmt(y0)}L#{fmt((5 * x0 + x1) / 6)},#{fmt((5 * y0 + y1) / 6)}"

    main =
      2..(n - 1)
      |> Enum.map_join("", fn i ->
        {ax, ay} = elem(pts, i - 2)
        {bx, by} = elem(pts, i - 1)
        {cx, cy} = elem(pts, i)
        bezier(ax, ay, bx, by, cx, cy)
      end)

    {fa_x, fa_y} = elem(pts, n - 2)
    {fb_x, fb_y} = elem(pts, n - 1)
    final_bez = bezier(fa_x, fa_y, fb_x, fb_y, fb_x, fb_y)
    final_line = "L#{fmt(fb_x)},#{fmt(fb_y)}"

    first <> main <> final_bez <> final_line
  end

  defp bezier(ax, ay, bx, by, cx, cy) do
    c1x = (2 * ax + bx) / 3
    c1y = (2 * ay + by) / 3
    c2x = (ax + 2 * bx) / 3
    c2y = (ay + 2 * by) / 3
    ex = (ax + 4 * bx + cx) / 6
    ey = (ay + 4 * by + cy) / 6

    "C#{fmt(c1x)},#{fmt(c1y)} #{fmt(c2x)},#{fmt(c2y)} #{fmt(ex)},#{fmt(ey)}"
  end

  @doc "Compact decimal formatting suitable for SVG coordinates."
  def fmt(n) when is_integer(n), do: Integer.to_string(n)
  def fmt(n) when is_float(n), do: :erlang.float_to_binary(n, [:compact, decimals: 2])
end
