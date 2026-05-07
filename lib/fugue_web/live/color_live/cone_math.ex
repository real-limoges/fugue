defmodule FugueWeb.ColorLive.ConeMath do
  @moduledoc """
  Pure plot-coordinate helpers for the /color cone plot and CIE chromaticity
  diagram. All wavelength → SVG coordinate math, gamut polygon helpers, and
  cone-label nudges live here so they're testable without booting a socket.
  """

  # ----- Cone plot -----

  @lambda_min 380.0
  @lambda_max 700.0
  @plot_x_left 60
  @plot_x_right 770
  @plot_y_top 30
  @plot_y_bottom 270

  # Approximate λ_max of each Stockman & Sharpe 2-deg fundamental,
  # used for label positioning.
  @cone_peak %{l: 565.0, m: 533.0, s: 442.0}

  # The chapter shows L shifted toward M (anomalous trichromacy / protanomaly).
  # The canonical baseline is intentionally omitted.
  @cone_shift %{l: -15.0, m: 0.0, s: 0.0}

  def lambda_min, do: @lambda_min
  def lambda_max, do: @lambda_max

  def cone_x_of(lambda) do
    span = @plot_x_right - @plot_x_left
    @plot_x_left + (lambda - @lambda_min) / (@lambda_max - @lambda_min) * span
  end

  def cone_y_of(response) do
    span = @plot_y_bottom - @plot_y_top
    @plot_y_bottom - response * span
  end

  def cone_peak(cone), do: @cone_peak[cone]
  def cone_shift(cone), do: @cone_shift[cone]
  def cone_label(:l), do: "L"
  def cone_label(:m), do: "M"
  def cone_label(:s), do: "S"

  # Horizontal nudge (in nm) so L and M labels don't collide when their
  # peaks land close together.
  def cone_label_dx(:l), do: 12
  def cone_label_dx(:m), do: -4
  def cone_label_dx(_), do: 0

  def cone_curve_points(cone) do
    shift = @cone_shift[cone]

    @lambda_min
    |> Stream.iterate(&(&1 + 2.0))
    |> Stream.take_while(&(&1 <= @lambda_max))
    |> Enum.map_join(" ", fn lambda ->
      x = Float.round(cone_x_of(lambda), 2)
      y = Float.round(cone_y_of(Fugue.Color.Cones.response(cone, lambda - shift)), 2)
      "#{x},#{y}"
    end)
  end

  # ----- CIE 1931 chromaticity diagram -----

  # CIE 1931 2-deg spectral locus (x, y) at 10 nm spacing, 380-700 nm.
  @spectral_locus [
    {380, 0.1741, 0.0050},
    {390, 0.1738, 0.0049},
    {400, 0.1733, 0.0048},
    {410, 0.1726, 0.0048},
    {420, 0.1714, 0.0051},
    {430, 0.1689, 0.0069},
    {440, 0.1644, 0.0109},
    {450, 0.1566, 0.0177},
    {460, 0.1440, 0.0297},
    {470, 0.1241, 0.0578},
    {480, 0.0913, 0.1327},
    {490, 0.0454, 0.2950},
    {500, 0.0082, 0.5384},
    {510, 0.0139, 0.7502},
    {520, 0.0743, 0.8338},
    {530, 0.1547, 0.8059},
    {540, 0.2296, 0.7543},
    {550, 0.3016, 0.6923},
    {560, 0.3731, 0.6245},
    {570, 0.4441, 0.5547},
    {580, 0.5125, 0.4866},
    {590, 0.5752, 0.4242},
    {600, 0.6270, 0.3725},
    {610, 0.6658, 0.3340},
    {620, 0.6915, 0.3083},
    {630, 0.7079, 0.2920},
    {640, 0.7190, 0.2809},
    {650, 0.7260, 0.2740},
    {660, 0.7300, 0.2700},
    {670, 0.7320, 0.2680},
    {680, 0.7334, 0.2666},
    {690, 0.7344, 0.2656},
    {700, 0.7347, 0.2653}
  ]

  # Display gamut primaries in CIE xy. White points (D65 ~ 0.3127, 0.3290)
  # are intentionally ignored; we draw the closed primary triangle only.
  @gamut_srgb [{0.640, 0.330}, {0.300, 0.600}, {0.150, 0.060}]
  @gamut_dci_p3 [{0.680, 0.320}, {0.265, 0.690}, {0.150, 0.060}]
  @gamut_rec2020 [{0.708, 0.292}, {0.170, 0.797}, {0.131, 0.046}]

  # Chromaticity (x, y) -> SVG (x, y) inside an 80x90 viewBox, with y flipped
  # so chromaticity-y grows upward. 100x scale: chromaticity 0.5 -> SVG 50.
  @gamut_view_h 90
  def chrom_x(x), do: x * 100
  def chrom_y(y), do: @gamut_view_h - y * 100 - 5

  def locus_polyline_points do
    Enum.map_join(@spectral_locus, " ", fn {_lambda, x, y} ->
      "#{Float.round(chrom_x(x), 2)},#{Float.round(chrom_y(y), 2)}"
    end)
  end

  def gamut_polygon_points(points) do
    Enum.map_join(points, " ", fn {x, y} ->
      "#{Float.round(chrom_x(x), 2)},#{Float.round(chrom_y(y), 2)}"
    end)
  end

  def srgb_points, do: gamut_polygon_points(@gamut_srgb)
  def p3_points, do: gamut_polygon_points(@gamut_dci_p3)
  def rec2020_points, do: gamut_polygon_points(@gamut_rec2020)
end
