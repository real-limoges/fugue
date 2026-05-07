defmodule Fugue.Color.WCSMockTest do
  use ExUnit.Case, async: true

  alias Fugue.Color.WCSMock

  test "grid dimensions" do
    assert WCSMock.hue_count() == 40
    assert WCSMock.lightness_count() == 8
  end

  test "languages/0 lists English and Berinmo" do
    assert WCSMock.languages() == [:english, :berinmo]
    assert WCSMock.language_label(:english) == "English"
    assert WCSMock.language_label(:berinmo) == "Berinmo"
  end

  test "modal/3 returns a known term and a consensus in (0, 1] for every chip" do
    for lang <- WCSMock.languages(),
        h <- 0..(WCSMock.hue_count() - 1),
        l <- 0..(WCSMock.lightness_count() - 1) do
      {term, consensus} = WCSMock.modal(lang, h, l)

      assert term in WCSMock.terms(lang),
             "lang=#{lang} h=#{h} l=#{l} returned unknown term #{term}"

      assert consensus > 0.0 and consensus <= 1.0
    end
  end

  test "term_color/1 returns a 7-character hex for every term in every language" do
    for lang <- WCSMock.languages(),
        term <- WCSMock.terms(lang) do
      hex = WCSMock.term_color(term)
      assert String.match?(hex, ~r/^#[0-9a-fA-F]{6}$/), "term=#{term} hex=#{hex}"
    end
  end

  test "chip_color/2 returns a 7-character hex for every chip" do
    for h <- 0..(WCSMock.hue_count() - 1),
        l <- 0..(WCSMock.lightness_count() - 1) do
      hex = WCSMock.chip_color(h, l)
      assert String.match?(hex, ~r/^#[0-9a-fA-F]{6}$/), "h=#{h} l=#{l} hex=#{hex}"
    end
  end

  test "Berinmo extremes are exactly the dark/light terms" do
    # By construction l <= 1 -> kel (white-ish), l >= 6 -> mehi (black-ish).
    for h <- 0..(WCSMock.hue_count() - 1) do
      assert {"kel", _} = WCSMock.modal(:berinmo, h, 0)
      assert {"kel", _} = WCSMock.modal(:berinmo, h, 1)
      assert {"mehi", _} = WCSMock.modal(:berinmo, h, 7)
    end
  end
end
