defmodule Fugue.Color.Spectrum do
  @moduledoc """
  Approximate sRGB rendering of a single visible wavelength.

  Bruton's piecewise approximation (1996) with edge intensity falloff and
  a gamma of 0.8. Not physically rigorous (real wavelength -> sRGB requires
  going through CIE XYZ and clipping out-of-gamut chromaticities), but
  reads correctly to the eye and is good enough for hero / closer strips.

  For accurate per-wavelength cone activations use `Fugue.Color.Cones`.
  """

  @gamma 0.8

  @doc """
  Returns an sRGB hex string (e.g. `"#aa3300"`) for `lambda` in nm.
  Clamps outside ~380..780.
  """
  def hex(lambda) when is_number(lambda) do
    {r, g, b} = rgb(lambda)
    "#" <> byte_hex(r) <> byte_hex(g) <> byte_hex(b)
  end

  defp rgb(lambda) do
    {r0, g0, b0} = base(lambda)
    f = falloff(lambda)
    {gamma(r0 * f), gamma(g0 * f), gamma(b0 * f)}
  end

  defp base(l) when l < 380, do: {0.0, 0.0, 0.0}
  defp base(l) when l < 440, do: {-(l - 440) / 60.0, 0.0, 1.0}
  defp base(l) when l < 490, do: {0.0, (l - 440) / 50.0, 1.0}
  defp base(l) when l < 510, do: {0.0, 1.0, -(l - 510) / 20.0}
  defp base(l) when l < 580, do: {(l - 510) / 70.0, 1.0, 0.0}
  defp base(l) when l < 645, do: {1.0, -(l - 645) / 65.0, 0.0}
  defp base(l) when l < 781, do: {1.0, 0.0, 0.0}
  defp base(_), do: {0.0, 0.0, 0.0}

  defp falloff(l) when l < 380, do: 0.0
  defp falloff(l) when l < 420, do: 0.3 + 0.7 * (l - 380) / 40.0
  defp falloff(l) when l < 700, do: 1.0
  defp falloff(l) when l < 781, do: 0.3 + 0.7 * (780 - l) / 80.0
  defp falloff(_), do: 0.0

  defp gamma(x) when x <= 0, do: 0
  defp gamma(x), do: round(:math.pow(x, @gamma) * 255)

  defp byte_hex(b) do
    b = max(0, min(255, b))
    s = Integer.to_string(b, 16)
    if byte_size(s) == 1, do: "0" <> s, else: s
  end
end
