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

  alias Fugue.Color.Srgb

  @protan {
    {0.152286, 1.052583, -0.204868},
    {0.114503, 0.786281, 0.099216},
    {-0.003882, -0.048116, 1.051998}
  }

  @doc """
  Returns the protanope-simulated sRGB hex for an sRGB hex input
  (e.g. `"#cc3333"` -> `"#7c7c33"`).
  """
  @spec protan_hex(String.t()) :: String.t()
  def protan_hex("#" <> hex) when byte_size(hex) == 6 do
    hex
    |> parse_hex()
    |> linearize()
    |> apply_matrix(@protan)
    |> delinearize()
    |> Srgb.hex()
  end

  defp parse_hex(<<r1, r2, g1, g2, b1, b2>>) do
    {hex_byte(r1, r2), hex_byte(g1, g2), hex_byte(b1, b2)}
  end

  defp hex_byte(c1, c2), do: String.to_integer(<<c1, c2>>, 16)

  defp linearize({r, g, b}), do: {Srgb.decode(r), Srgb.decode(g), Srgb.decode(b)}

  defp apply_matrix({r, g, b}, {{a, bb, cc}, {d, e, f}, {gg, h, i}}) do
    {a * r + bb * g + cc * b, d * r + e * g + f * b, gg * r + h * g + i * b}
  end

  defp delinearize({r, g, b}), do: {Srgb.encode(r), Srgb.encode(g), Srgb.encode(b)}
end
