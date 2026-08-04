defmodule Fugue.Fuzzy.Defuzzify do
  @moduledoc """
  Defuzzification methods, ported from Hazy's `Hazy.Core.Defuzzify`. Takes a
  list of `{fuzzy_set, degree}` pairs (clipped Mamdani consequents), samples
  the max-aggregated curve across their combined universe, and reduces it to
  a crisp value (or, via `sampled_aggregation/1`, returns the raw curve for
  visualization).
  """

  @default_resolution 200

  @type method ::
          :centroid
          | :bisector
          | :mean_of_maximum
          | :smallest_of_max
          | :largest_of_max
          | {:custom, ([{map(), float()}] -> float())}

  @doc """
  Sample the aggregated (max-clipped) membership curve across the combined
  universe of all clipped consequents. Returns `[]` when no consequents
  fire. Used to power the Mamdani inference trace's output curves.
  """
  def sampled_aggregation([]), do: []

  def sampled_aggregation(pairs) do
    {lo, hi} = combined_universe(pairs)
    xs = sample_points(@default_resolution, lo, hi)
    Enum.map(xs, fn x -> {x, aggregated_mf(pairs, x)} end)
  end

  @doc "Defuzzify a list of `{fuzzy_set, degree}` pairs via the given method."
  def defuzzify({:custom, fun}, pairs), do: fun.(pairs)
  def defuzzify(_method, []), do: 0.0

  def defuzzify(method, pairs) do
    {lo, hi} = combined_universe(pairs)
    xs = sample_points(@default_resolution, lo, hi)
    vals = Enum.map(xs, fn x -> {x, aggregated_mf(pairs, x)} end)

    case method do
      :centroid -> centroid(vals, lo, hi)
      :bisector -> bisector(vals, lo, hi)
      :smallest_of_max -> extreme_of_max(vals, lo, hi, :first)
      :largest_of_max -> extreme_of_max(vals, lo, hi, :last)
      :mean_of_maximum -> mean_of_maximum(vals, lo, hi)
    end
  end

  defp sample_points(n, lo, hi) do
    step = (hi - lo) / (n - 1)
    for i <- 0..(n - 1), do: lo + i * step
  end

  defp combined_universe(pairs) do
    {los, his} = pairs |> Enum.map(fn {fs, _degree} -> fs.universe end) |> Enum.unzip()
    {Enum.min(los), Enum.max(his)}
  end

  defp aggregated_mf(pairs, x) do
    pairs |> Enum.map(fn {fs, alpha} -> min(alpha, fs.mf.(x)) end) |> Enum.max()
  end

  defp centroid(vals, lo, hi) do
    num = Enum.reduce(vals, 0.0, fn {x, m}, acc -> acc + x * m end)
    den = Enum.reduce(vals, 0.0, fn {_x, m}, acc -> acc + m end)
    if den == 0.0, do: (lo + hi) / 2, else: num / den
  end

  defp bisector(vals, lo, hi) do
    total_area = Enum.reduce(vals, 0.0, fn {_x, m}, acc -> acc + m end)
    if total_area == 0.0, do: (lo + hi) / 2, else: bisect(vals, total_area / 2)
  end

  defp bisect([], _remaining), do: 0.0
  defp bisect([{x, _m}], _remaining), do: x

  defp bisect([{x, m} | rest], remaining) do
    if remaining <= m, do: x, else: bisect(rest, remaining - m)
  end

  defp extreme_of_max(vals, lo, hi, which) do
    max_mu = vals |> Enum.map(fn {_x, m} -> m end) |> Enum.max()

    if max_mu == 0.0 do
      (lo + hi) / 2
    else
      at_max = Enum.filter(vals, fn {_x, m} -> m == max_mu end)
      {x, _m} = if which == :first, do: List.first(at_max), else: List.last(at_max)
      x
    end
  end

  defp mean_of_maximum(vals, lo, hi) do
    max_mu = vals |> Enum.map(fn {_x, m} -> m end) |> Enum.max()

    if max_mu == 0.0 do
      (lo + hi) / 2
    else
      max_pts =
        vals |> Enum.filter(fn {_x, m} -> m == max_mu end) |> Enum.map(fn {x, _m} -> x end)

      Enum.sum(max_pts) / length(max_pts)
    end
  end
end
