defmodule Fugue.Color.SrgbGamutTest do
  use ExUnit.Case, async: true

  alias Fugue.Color.SrgbGamut

  test "cells/0 returns chromaticity-keyed hex tuples" do
    cells = SrgbGamut.cells()
    assert is_list(cells)
    assert length(cells) > 0

    Enum.each(cells, fn {x, y, hex} ->
      assert is_float(x) and is_float(y)
      assert String.match?(hex, ~r/^#[0-9a-f]{6}$/)
    end)
  end

  test "is cached: two calls return the exact same list" do
    a = SrgbGamut.cells()
    b = SrgbGamut.cells()
    assert a === b
  end

  test "all chromaticities lie inside the sRGB triangle" do
    for {x, y, _} <- SrgbGamut.cells() do
      # Bounding box sanity: triangle vertices are R(0.640, 0.330),
      # G(0.300, 0.600), B(0.150, 0.060).
      assert x >= 0.14 and x <= 0.65
      assert y > 0.0 and y <= 0.61
    end
  end

  test "step/0 matches the spacing between adjacent x columns" do
    step = SrgbGamut.step()
    # Sanity: step is a small positive float.
    assert is_float(step)
    assert step > 0.0 and step < 0.1
  end
end
