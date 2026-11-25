defmodule Fugue.Color.SrgbTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Fugue.Color.Srgb

  doctest Srgb

  property "decode then encode gives back every 8-bit value" do
    check all(byte <- integer(0..255)) do
      assert byte |> Srgb.decode() |> Srgb.encode() == byte
    end
  end

  test "hex pads single-digit channels" do
    assert Srgb.hex({0, 5, 15}) == "#00050F"
  end
end
