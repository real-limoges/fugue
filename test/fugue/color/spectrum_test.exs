defmodule Fugue.Color.SpectrumTest do
  use ExUnit.Case, async: true

  alias Fugue.Color.Spectrum

  doctest Fugue.Color.Spectrum

  test "returns a 7-character hex string" do
    for l <- 380..780//20 do
      hex = Spectrum.hex(l)
      assert String.length(hex) == 7
      assert String.starts_with?(hex, "#")
      assert String.match?(hex, ~r/^#[0-9a-fA-F]{6}$/)
    end
  end

  test "outside the visible range returns black" do
    assert Spectrum.hex(300) == "#000000"
    assert Spectrum.hex(800) == "#000000"
  end

  test "yellow-ish wavelengths are red+green dominated" do
    # ~580 nm should be near-yellow: R and G high, B low.
    "#" <> hex = Spectrum.hex(580)
    {r, g, b} = parse(hex)
    assert r > 200
    assert g > 200
    assert b < 80
  end

  test "deep blue wavelengths are blue dominated" do
    "#" <> hex = Spectrum.hex(450)
    {r, g, b} = parse(hex)
    assert b > 200
    assert r < 80
    # 450 nm sits in the blue-only region of the piecewise (l < 490).
    assert g < 80
  end

  test "red wavelengths are red dominated" do
    "#" <> hex = Spectrum.hex(680)
    {r, g, b} = parse(hex)
    assert r > 150
    assert g < 50
    assert b < 50
  end

  defp parse(<<r1, r2, g1, g2, b1, b2>>) do
    {String.to_integer(<<r1, r2>>, 16), String.to_integer(<<g1, g2>>, 16),
     String.to_integer(<<b1, b2>>, 16)}
  end
end
