defmodule Fugue.Color.Srgb do
  @moduledoc """
  The sRGB transfer curve (IEC 61966-2-1) and hex formatting, shared by
  `Fugue.Color.Daltonize`, `Fugue.Color.SrgbGamut` and
  `Fugue.Color.Spectrum`.
  """

  @typedoc "An 8-bit channel value."
  @type byte_value :: 0..255

  @doc """
  Encode a linear-light channel as an 8-bit sRGB value. Values outside
  [0, 1] are clamped first.

      iex> Fugue.Color.Srgb.encode(1.0)
      255

      iex> Fugue.Color.Srgb.encode(-0.2)
      0
  """
  @spec encode(number()) :: byte_value()
  def encode(linear) do
    c = linear |> max(0.0) |> min(1.0)
    n = if c <= 0.0031308, do: c * 12.92, else: 1.055 * :math.pow(c, 1.0 / 2.4) - 0.055
    round(n * 255)
  end

  @doc """
  Decode an 8-bit sRGB value to linear light in [0, 1].

      iex> Fugue.Color.Srgb.decode(255)
      1.0
  """
  @spec decode(byte_value()) :: float()
  def decode(byte) do
    n = byte / 255.0
    if n <= 0.04045, do: n / 12.92, else: :math.pow((n + 0.055) / 1.055, 2.4)
  end

  @doc """
  Format three 8-bit channels as an uppercase `#RRGGBB` string.

      iex> Fugue.Color.Srgb.hex({255, 10, 0})
      "#FF0A00"
  """
  @spec hex({byte_value(), byte_value(), byte_value()}) :: String.t()
  def hex({r, g, b}), do: "#" <> byte_hex(r) <> byte_hex(g) <> byte_hex(b)

  defp byte_hex(n), do: n |> Integer.to_string(16) |> String.pad_leading(2, "0")
end
