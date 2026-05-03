defmodule Fugue.Color.WCSMock do
  @moduledoc """
  Placeholder WCS-style chip data for the color chapter section 5.

  The real World Color Survey aggregation (chip_id -> modal_term + consensus)
  lives in the Timbre repo and is not yet bootstrapped. This module fakes
  the shape of that output for two languages so the section 5 splash has something
  to render against.

  Grid: 40 hue columns x 8 lightness rows (Munsell-like, chroma dropped).
  English categorization is the standard Berlin & Kay basic-color terms.
  Berinmo categorization here is a *sketch* of the Roberson et al. findings
  -- a wider yellow-green term (`wor`) and a cool-side term (`nol`) covering
  green-through-blue. Replace with real WCS data when Timbre ships.
  """

  @hue_count 40
  @lightness_count 8

  def hue_count, do: @hue_count
  def lightness_count, do: @lightness_count

  @term_colors %{
    "white" => "#f5f5f5",
    "black" => "#0d0d0d",
    "gray" => "#737373",
    "red" => "#dc2626",
    "orange" => "#ea580c",
    "yellow" => "#facc15",
    "green" => "#16a34a",
    "blue" => "#2563eb",
    "purple" => "#9333ea",
    "pink" => "#ec4899",
    "brown" => "#7c2d12",
    "kel" => "#f5f5f5",
    "mehi" => "#0d0d0d",
    "wap" => "#cc3300",
    "wor" => "#bba300",
    "nol" => "#0e6650"
  }

  def term_color(term), do: Map.fetch!(@term_colors, term)

  @doc "Approximate base sRGB hex for a chip at hue index h (0..39) and lightness row l (0..7)."
  def chip_color(h, l) do
    lambda = 380 + h / @hue_count * 320.0
    base = Fugue.Color.Spectrum.hex(lambda)
    blend_lightness(base, l)
  end

  defp blend_lightness("#" <> hex, l) do
    {r, g, b} = parse(hex)
    t = (l + 0.5) / @lightness_count

    {wr, wg, wb} =
      cond do
        t < 0.5 ->
          k = (0.5 - t) * 2
          {r + (255 - r) * k, g + (255 - g) * k, b + (255 - b) * k}

        true ->
          k = (t - 0.5) * 2
          {r * (1 - k), g * (1 - k), b * (1 - k)}
      end

    "#" <> byte(wr) <> byte(wg) <> byte(wb)
  end

  defp parse(<<r1, r2, g1, g2, b1, b2>>) do
    {String.to_integer(<<r1, r2>>, 16), String.to_integer(<<g1, g2>>, 16),
     String.to_integer(<<b1, b2>>, 16)}
  end

  defp byte(v) do
    v = round(v) |> max(0) |> min(255)
    s = Integer.to_string(v, 16)
    if byte_size(s) == 1, do: "0" <> s, else: s
  end

  @doc """
  Modal term + consensus (0..1) for `lang` at chip (h, l).
  Languages: `:english` and `:berinmo`.
  """
  def modal(:english, h, l) do
    cond do
      l == 0 -> {"white", 0.92}
      l == 7 -> {"black", 0.92}
      l == 1 and (h <= 4 or h >= 36) -> {"pink", 0.62}
      l >= 6 and (h <= 4 or h >= 35) -> {"brown", 0.7}
      l >= 6 -> {"black", 0.55}
      l <= 1 -> {"white", 0.6}
      h <= 2 or h >= 38 -> {"red", 0.88}
      h <= 5 -> {"orange", 0.75}
      h <= 9 -> {"yellow", 0.85}
      h <= 18 -> {"green", 0.85}
      h <= 28 -> {"blue", 0.85}
      h <= 33 -> {"purple", 0.7}
      true -> {"pink", 0.7}
    end
  end

  def modal(:berinmo, h, l) do
    cond do
      l <= 1 -> {"kel", 0.9}
      l >= 6 -> {"mehi", 0.9}
      h <= 4 or h >= 35 -> {"wap", 0.8}
      h <= 14 -> {"wor", 0.85}
      true -> {"nol", 0.85}
    end
  end

  def languages, do: [:english, :berinmo]

  def language_label(:english), do: "English"
  def language_label(:berinmo), do: "Berinmo"

  @doc "Set of distinct term names used by `lang`, in display order."
  def terms(:english), do: ~w(white pink red orange yellow green blue purple brown black)
  def terms(:berinmo), do: ~w(kel wap wor nol mehi)
end
