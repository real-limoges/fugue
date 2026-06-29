defmodule Fugue.Color.WCSTest do
  use ExUnit.Case, async: true

  alias Fugue.Color.WCS

  @hex ~r/^#[0-9a-fA-F]{6}$/

  test "grid dimensions" do
    assert WCS.hue_count() == 40
    assert WCS.lightness_count() == 8
  end

  test "languages/0 lists the four surveyed languages with labels" do
    assert WCS.languages() == [:tarahumara, :kalam, :nafaanra, :walpiri]

    for lang <- WCS.languages() do
      assert is_binary(WCS.language_label(lang))
      assert WCS.language_label(lang) != ""
    end
  end

  test "modal/3 returns a known term code and a consensus in (0, 1] for every chip" do
    for lang <- WCS.languages(),
        h <- 0..(WCS.hue_count() - 1),
        l <- 0..(WCS.lightness_count() - 1) do
      {code, consensus} = WCS.modal(lang, h, l)

      assert code in WCS.terms(lang),
             "lang=#{lang} h=#{h} l=#{l} returned unlisted term #{code}"

      assert consensus > 0.0 and consensus <= 1.0,
             "lang=#{lang} h=#{h} l=#{l} consensus #{consensus} out of range"
    end
  end

  test "term_color/2 returns a 7-character hex for every modal term in every language" do
    for lang <- WCS.languages(),
        code <- WCS.terms(lang) do
      hex = WCS.term_color(lang, code)
      assert String.match?(hex, @hex), "lang=#{lang} code=#{code} hex=#{hex}"
    end
  end

  test "term_label/2 decodes every modal term to a non-empty transcription" do
    for lang <- WCS.languages(),
        code <- WCS.terms(lang) do
      label = WCS.term_label(lang, code)
      assert label != "", "lang=#{lang} code=#{code} has empty transcription"
    end
  end

  test "chip_color/2 returns a 7-character hex for every chip" do
    for h <- 0..(WCS.hue_count() - 1),
        l <- 0..(WCS.lightness_count() - 1) do
      hex = WCS.chip_color(h, l)
      assert String.match?(hex, @hex), "h=#{h} l=#{l} hex=#{hex}"
    end
  end
end
