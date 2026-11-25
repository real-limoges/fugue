defmodule Fugue.Fuzzy.Defuzzify do
  @moduledoc """
  Centroid defuzzification, ported from Hazy's `Hazy.Core.Defuzzify`. Takes
  a list of `{fuzzy_set, degree}` pairs (clipped Mamdani consequents),
  samples the max-aggregated curve across their combined universe, and
  either returns that curve (`sampled_aggregation/1`, for the inference
  trace) or reduces it to its centroid (`centroid/1`).

  Hazy also offered bisector and the max-based methods; nothing here used
  them, so they were deleted on 2026-11-25.
  """

  alias Fugue.Fuzzy.Inference.Types

  @resolution 200

  @typedoc "A clipped consequent: a fuzzy set and the degree its rule fired at."
  @type pair :: {Types.fuzzy_set(), Types.degree()}

  @doc """
  Sample the aggregated (max-clipped) membership curve across the combined
  universe of all clipped consequents. Returns `[]` when no consequents
  fire. Used to power the Mamdani inference trace's output curves.
  """
  @spec sampled_aggregation([pair()]) :: Types.curve()
  def sampled_aggregation([]), do: []

  def sampled_aggregation(pairs) do
    {lo, hi} = combined_universe(pairs)
    step = (hi - lo) / (@resolution - 1)

    for i <- 0..(@resolution - 1) do
      x = lo + i * step
      {x, aggregated_mf(pairs, x)}
    end
  end

  @doc """
  The centroid of the aggregated curve. With no consequents firing it is
  0.0; with consequents that all clip to zero, the middle of their
  universe.
  """
  @spec centroid([pair()]) :: float()
  def centroid([]), do: 0.0

  def centroid(pairs) do
    curve = sampled_aggregation(pairs)
    num = Enum.reduce(curve, 0.0, fn {x, m}, acc -> acc + x * m end)
    den = Enum.reduce(curve, 0.0, fn {_x, m}, acc -> acc + m end)

    if den == 0.0 do
      {lo, hi} = combined_universe(pairs)
      (lo + hi) / 2
    else
      num / den
    end
  end

  defp combined_universe(pairs) do
    {los, his} = pairs |> Enum.map(fn {fs, _degree} -> fs.universe end) |> Enum.unzip()
    {Enum.min(los), Enum.max(his)}
  end

  defp aggregated_mf(pairs, x) do
    pairs |> Enum.map(fn {fs, alpha} -> min(alpha, fs.mf.(x)) end) |> Enum.max()
  end
end
