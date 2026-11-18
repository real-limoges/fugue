defmodule Fugue.Color.SrgbGamutTest do
  use ExUnit.Case, async: true

  alias Fugue.Color.SrgbGamut

  # Reads the PNG back: its size from IHDR, and its pixels from the one
  # IDAT chunk, as rows of RGB bytes with the filter byte dropped.
  defp decode(png) do
    <<137, "PNG", 13, 10, 26, 10, rest::binary>> = png
    chunks = read_chunks(rest, %{})
    <<width::32, height::32, 8, 2, 0, 0, 0>> = chunks["IHDR"]
    pixels = :zlib.uncompress(chunks["IDAT"])
    row_bytes = width * 3
    rows = for <<0, row::binary-size(^row_bytes) <- pixels>>, do: row
    %{width: width, height: height, rows: rows}
  end

  defp read_chunks(<<>>, acc), do: acc

  defp read_chunks(
         <<len::32, type::binary-size(4), data::binary-size(len), crc::32, rest::binary>>,
         acc
       ) do
    assert crc == :erlang.crc32(type <> data), "bad CRC on #{type}"
    read_chunks(rest, Map.put(acc, type, data))
  end

  # The pixel nearest chromaticity (x, y).
  defp pixel_at(%{rows: rows}, x, y) do
    b = SrgbGamut.bounds()
    step = SrgbGamut.step()
    col = trunc((x - b.x_min) / step)
    row = trunc((b.y_max - y) / step)
    skip = col * 3
    <<_::binary-size(^skip), r, g, bl, _::binary>> = Enum.at(rows, row)
    {r, g, bl}
  end

  test "png/0 is a valid PNG with one pixel per grid step" do
    image = decode(SrgbGamut.png())
    b = SrgbGamut.bounds()
    step = SrgbGamut.step()

    assert image.width == round((b.x_max - b.x_min) / step)
    assert image.height == round((b.y_max - b.y_min) / step)
    assert length(image.rows) == image.height
  end

  test "the primaries come out as their own colors" do
    image = decode(SrgbGamut.png())

    {r, g, b} = pixel_at(image, 0.640, 0.330)
    assert r == 255 and g < 40 and b < 40

    {r, g, b} = pixel_at(image, 0.300, 0.600)
    assert g == 255 and r < 80 and b < 40

    {r, g, b} = pixel_at(image, 0.150, 0.060)
    assert b == 255 and r < 40 and g < 40
  end

  test "D65 white is near-neutral" do
    {r, g, b} = pixel_at(decode(SrgbGamut.png()), 0.3127, 0.3290)
    assert Enum.max([r, g, b]) - Enum.min([r, g, b]) < 12
  end

  test "is cached: two calls return the same binary" do
    assert SrgbGamut.png() === SrgbGamut.png()
  end

  test "stays small enough to inline" do
    assert byte_size(SrgbGamut.png()) < 40_000
  end
end
