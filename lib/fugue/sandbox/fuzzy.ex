defmodule Fugue.Sandbox.Fuzzy do
  @moduledoc """
  Pure triangular membership functions for the sandbox fuzzy-math experiments.
  No state, no I/O — just math that the LiveView re-runs when parameters change.
  """

  # {name, default_peak_celsius, hex color}. Palette picked for maximum hue
  # contrast between adjacent bands rather than a literal temperature gradient
  # so stacked bands stay distinguishable without relying on red/green.
  @base_mfs [
    {"cold", 10.0, "#a78bfa"},
    {"cool", 17.0, "#38bdf8"},
    {"mild", 24.0, "#facc15"},
    {"warm", 31.0, "#fb923c"},
    {"hot", 38.0, "#ec4899"}
  ]

  @default_half_width 7.0

  @doc "Default MF set used on first mount (center_offset 0, spread 1.0)."
  def default_mfs, do: build_mfs(0.0, 1.0)

  @doc """
  Build the five temperature MFs. `center_offset` shifts every peak along the
  temperature axis; `spread` multiplies the triangle half-width so adjacent
  sets overlap more or less.
  """
  def build_mfs(center_offset, spread)
      when is_number(center_offset) and is_number(spread) do
    half = @default_half_width * spread

    for {name, center, color} <- @base_mfs do
      peak = center + center_offset

      %{
        name: name,
        color: color,
        a: peak - half,
        b: peak,
        c: peak + half
      }
    end
  end

  @doc "Triangular membership: 0 outside [a, c], 1 at b, linear ramps on either side."
  def triangular(x, a, b, c)
      when is_number(x) and is_number(a) and is_number(b) and is_number(c) do
    cond do
      x <= a -> 0.0
      x < b and b > a -> (x - a) / (b - a)
      x == b -> 1.0
      x < c and c > b -> (c - x) / (c - b)
      true -> 0.0
    end
  end

  def triangular(_, _, _, _), do: 0.0

  @doc """
  Normalized memberships for one value across all MFs. Normalization makes
  the stacked area chart fill the full height even when raw memberships
  don't sum to 1 (e.g. when spread is narrow).
  """
  def memberships(x, mfs) do
    raw = Enum.map(mfs, fn mf -> {mf.name, triangular(x, mf.a, mf.b, mf.c)} end)
    total = Enum.reduce(raw, 0.0, fn {_, v}, acc -> acc + v end)

    cond do
      total > 0 -> Map.new(raw, fn {name, v} -> {name, v / total} end)
      true -> Map.new(raw, fn {name, _} -> {name, 0.0} end)
    end
  end

  @doc """
  For every weather row, compute fuzzy memberships on its TMAX value.
  Rows without a TMAX get all zeros (rendered as a gap in the chart).
  """
  def bands(rows, mfs) do
    zero = Map.new(mfs, fn mf -> {mf.name, 0.0} end)

    Enum.map(rows, fn row ->
      mems =
        if is_nil(row.tmax) do
          zero
        else
          memberships(row.tmax, mfs)
        end

      %{date: row.date, memberships: mems}
    end)
  end
end
