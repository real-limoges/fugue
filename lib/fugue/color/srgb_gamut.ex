defmodule Fugue.Color.SrgbGamut do
  @moduledoc """
  Tiles the sRGB chromaticity triangle with cells, each colored with the
  brightest sRGB-displayable color at its (x, y) chromaticity. Used to
  fill the sRGB region in the gamut splash so the reader sees what a
  gamut actually contains, instead of an empty triangle.

  Per chromaticity we set Y = 1, compute (X, Y, Z), convert to linear
  sRGB, then scale so the brightest channel lands at 1.0 (most saturated
  displayable color at that chromaticity), apply sRGB gamma, and emit a
  hex string.
  """

  # CIE XYZ -> linear sRGB, D65 (IEC 61966-2-1).
  @m11 3.2406
  @m12 -1.5372
  @m13 -0.4986
  @m21 -0.9689
  @m22 1.8758
  @m23 0.0415
  @m31 0.0557
  @m32 -0.2040
  @m33 1.0570

  # sRGB primaries in CIE 1931 xy.
  @red {0.640, 0.330}
  @green {0.300, 0.600}
  @blue {0.150, 0.060}

  @step 0.005

  @doc """
  Returns `[{cx, cy, hex}, ...]` covering the sRGB chromaticity triangle.
  Cached in `:persistent_term` after first call.
  """
  def cells do
    case :persistent_term.get({__MODULE__, :cells}, nil) do
      nil ->
        cs = compute()
        :persistent_term.put({__MODULE__, :cells}, cs)
        cs

      cs ->
        cs
    end
  end

  @doc "Cell step in chromaticity units."
  def step, do: @step

  defp compute do
    xs = float_seq(0.14, 0.65, @step)
    ys = float_seq(0.05, 0.61, @step)

    for x <- xs, y <- ys, y > 0, inside_triangle?(x, y) do
      {x, y, hex_at(x, y)}
    end
  end

  defp float_seq(a, b, step) do
    n = round((b - a) / step)
    Enum.map(0..n, &(a + &1 * step))
  end

  defp inside_triangle?(px, py) do
    {ax, ay} = @red
    {bx, by} = @green
    {cx, cy} = @blue

    d1 = cross(px - bx, py - by, ax - bx, ay - by)
    d2 = cross(px - cx, py - cy, bx - cx, by - cy)
    d3 = cross(px - ax, py - ay, cx - ax, cy - ay)

    has_neg = d1 < 0 or d2 < 0 or d3 < 0
    has_pos = d1 > 0 or d2 > 0 or d3 > 0
    not (has_neg and has_pos)
  end

  defp cross(ax, ay, bx, by), do: ax * by - bx * ay

  defp hex_at(x, y) do
    big_x = x / y
    big_y = 1.0
    big_z = (1.0 - x - y) / y

    r = @m11 * big_x + @m12 * big_y + @m13 * big_z
    g = @m21 * big_x + @m22 * big_y + @m23 * big_z
    b = @m31 * big_x + @m32 * big_y + @m33 * big_z

    m = Enum.max([r, g, b])

    {r, g, b} =
      if m > 0 do
        {r / m, g / m, b / m}
      else
        {0.0, 0.0, 0.0}
      end

    r = clamp01(r)
    g = clamp01(g)
    b = clamp01(b)

    "#" <> byte(gamma(r)) <> byte(gamma(g)) <> byte(gamma(b))
  end

  defp clamp01(v) when v < 0.0, do: 0.0
  defp clamp01(v) when v > 1.0, do: 1.0
  defp clamp01(v), do: v

  defp gamma(c) when c <= 0.0031308, do: 12.92 * c
  defp gamma(c), do: 1.055 * :math.pow(c, 1.0 / 2.4) - 0.055

  defp byte(c) do
    (c * 255)
    |> max(0)
    |> min(255)
    |> round()
    |> Integer.to_string(16)
    |> String.pad_leading(2, "0")
    |> String.downcase()
  end
end
