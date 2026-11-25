defmodule Fugue.Color.SrgbGamut do
  @moduledoc """
  Paints the sRGB chromaticity triangle as a small PNG, one pixel per
  grid point, each the brightest sRGB-displayable color at its (x, y)
  chromaticity. The gamut splash stretches it over the triangle and clips
  it there, so the reader sees what a gamut actually contains instead of
  an empty triangle.

  Per chromaticity we set Y = 1, compute (X, Y, Z), convert to linear
  sRGB, then scale so the brightest channel lands at 1.0 (most saturated
  displayable color at that chromaticity), and apply sRGB gamma.

  Every pixel in the bounding box gets a color, including the ones outside
  the triangle (their channels clamp). The splash clips those away, and
  coloring them keeps the browser's smoothing from blending the triangle's
  edge toward transparent.

  It used to be one SVG `rect` per in-gamut point, about 4,500 of them:
  340 KB of `/color`'s HTML, kept again in every LiveView's render tree.
  The PNG is a few KB.
  """

  alias Fugue.Color.Srgb

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

  @step 0.005

  # The grid's bounding box in chromaticity, covering the sRGB primaries
  # R(0.640, 0.330), G(0.300, 0.600), B(0.150, 0.060).
  @x_min 0.14
  @x_max 0.65
  @y_min 0.05
  @y_max 0.61

  @typedoc """
  Where the image sits, in chromaticity units: the edges of the outermost
  pixels, half a step beyond the outermost grid points.
  """
  @type bounds :: %{x_min: float(), x_max: float(), y_min: float(), y_max: float()}

  @doc """
  The gamut as a PNG binary. The top row is the highest y, as on the
  diagram. Cached in `:persistent_term` after the first call.
  """
  @spec png() :: binary()
  def png do
    case :persistent_term.get({__MODULE__, :png}, nil) do
      nil ->
        png = encode_png(length(xs()), length(ys()), rows())
        :persistent_term.put({__MODULE__, :png}, png)
        png

      png ->
        png
    end
  end

  @doc "Where the PNG's outer edges fall, in chromaticity units."
  @spec bounds() :: bounds()
  def bounds do
    half = @step / 2

    %{
      x_min: @x_min - half,
      x_max: @x_max + half,
      y_min: @y_min - half,
      y_max: @y_max + half
    }
  end

  @doc "Grid spacing in chromaticity units; one pixel of the PNG."
  @spec step() :: float()
  def step, do: @step

  defp xs, do: float_seq(@x_min, @x_max, @step)
  defp ys, do: float_seq(@y_min, @y_max, @step)

  defp float_seq(a, b, step) do
    n = round((b - a) / step)
    Enum.map(0..n, &(a + &1 * step))
  end

  # One binary of RGB bytes per row, top row first.
  defp rows do
    for y <- Enum.reverse(ys()) do
      for x <- xs(), into: <<>>, do: rgb_at(x, y)
    end
  end

  defp rgb_at(x, y) do
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

    <<Srgb.encode(r), Srgb.encode(g), Srgb.encode(b)>>
  end

  # A minimal truecolor PNG: 8 bits per channel, no alpha, no interlace,
  # filter type 0 (none) on every row.
  defp encode_png(width, height, rows) do
    header = <<width::32, height::32, 8, 2, 0, 0, 0>>
    pixels = for row <- rows, into: <<>>, do: <<0>> <> row

    <<137, "PNG", 13, 10, 26, 10>> <>
      chunk("IHDR", header) <> chunk("IDAT", :zlib.compress(pixels)) <> chunk("IEND", <<>>)
  end

  defp chunk(type, data) do
    <<byte_size(data)::32, type::binary, data::binary, :erlang.crc32(type <> data)::32>>
  end
end
