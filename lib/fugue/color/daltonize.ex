defmodule Fugue.Color.Daltonize do
  @moduledoc """
  Color-vision-deficiency simulation in sRGB.

  Uses the Machado, Oliveira & Fernandes (2009) severity-1.0 protanope
  matrix in linear sRGB. Reference:

      Machado, G. M., Oliveira, M. M., & Fernandes, L. A. F. (2009).
      A physiologically-based model for simulation of color vision deficiency.
      IEEE Trans. Vis. Comput. Graphics, 15(6), 1291-1298.

  Severity is fixed at 1.0 (full protanopia) for now. Anomalous-trichromat
  (intermediate severity) variants live in the same family of matrices and
  can be added when the chapter wants the gradient.
  """

  @protan {
    {0.152286, 1.052583, -0.204868},
    {0.114503, 0.786281, 0.099216},
    {-0.003882, -0.048116, 1.051998}
  }

  @doc """
  Returns the protanope-simulated sRGB hex for an sRGB hex input
  (e.g. `"#cc3333"` -> `"#7c7c33"`).
  """
  def protan_hex("#" <> hex) when byte_size(hex) == 6 do
    hex
    |> parse_hex()
    |> linearize()
    |> apply_matrix(@protan)
    |> delinearize()
    |> format_hex()
  end

  defp parse_hex(<<r1, r2, g1, g2, b1, b2>>) do
    {hex_byte(r1, r2), hex_byte(g1, g2), hex_byte(b1, b2)}
  end

  defp hex_byte(c1, c2), do: String.to_integer(<<c1, c2>>, 16)

  defp linearize({r, g, b}) do
    {srgb_to_lin(r), srgb_to_lin(g), srgb_to_lin(b)}
  end

  defp srgb_to_lin(c) do
    n = c / 255.0
    if n <= 0.04045, do: n / 12.92, else: :math.pow((n + 0.055) / 1.055, 2.4)
  end

  defp apply_matrix({r, g, b}, {{a, bb, cc}, {d, e, f}, {gg, h, i}}) do
    {a * r + bb * g + cc * b, d * r + e * g + f * b, gg * r + h * g + i * b}
  end

  defp delinearize({r, g, b}) do
    {lin_to_srgb(r), lin_to_srgb(g), lin_to_srgb(b)}
  end

  defp lin_to_srgb(c) do
    c = c |> max(0.0) |> min(1.0)
    n = if c <= 0.0031308, do: c * 12.92, else: 1.055 * :math.pow(c, 1.0 / 2.4) - 0.055
    round(n * 255)
  end

  defp format_hex({r, g, b}) do
    "#" <> byte_hex(r) <> byte_hex(g) <> byte_hex(b)
  end

  defp byte_hex(n) do
    n |> Integer.to_string(16) |> String.pad_leading(2, "0")
  end
end
