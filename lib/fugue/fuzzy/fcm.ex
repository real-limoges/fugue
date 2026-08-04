defmodule Fugue.Fuzzy.FCM do
  @moduledoc """
  Fuzzy C-Means clustering, ported from Hazy's `Hazy.Algorithms.FCM` and
  `Hazy.Algorithms.FCM.Internal`. Points and centers are plain lists of
  floats; membership matrices are lists of rows (one row per point, one
  column per cluster).
  """

  @doc "Default config: `fuzziness: 2.0, epsilon: 1e-5, max_iter: 100`."
  def default_config(clusters) do
    %{clusters: clusters, fuzziness: 2.0, epsilon: 1.0e-5, max_iter: 100}
  end

  @doc "Run FCM on `xs` (a list of points). Returns `%{centers:, membership:, iterations:}`."
  def run(config, xs) do
    u0 = init_membership(length(xs), config.clusters)
    {centers, membership, iterations} = iterate(config, xs, u0)
    %{centers: centers, membership: membership, iterations: iterations}
  end

  @doc """
  Deterministic pseudo-seeding (not true randomness -- load-bearing for
  reproducible tests, do not swap for real randomness), row-normalized so
  each point's membership across clusters sums to 1.
  """
  def init_membership(n, c) do
    for i <- 0..(n - 1) do
      raw = for j <- 0..(c - 1), do: 1.0 + 0.1 * :math.sin(i * 7 + j * 13)
      total = Enum.sum(raw)
      Enum.map(raw, &(&1 / total))
    end
  end

  @doc "Weighted centroid update: `center_j[dim] = sum_i(u_ij^m * x_i[dim]) / sum_i(u_ij^m)`."
  def update_centers(m, u, xs) do
    c = u |> hd() |> length()
    d = xs |> hd() |> length()
    weights = Enum.map(u, fn row -> Enum.map(row, &:math.pow(&1, m)) end)

    for j <- 0..(c - 1) do
      wsum = weights |> Enum.map(&Enum.at(&1, j)) |> Enum.sum()

      for dim <- 0..(d - 1) do
        num =
          weights
          |> Enum.zip(xs)
          |> Enum.map(fn {wrow, x} -> Enum.at(wrow, j) * Enum.at(x, dim) end)
          |> Enum.sum()

        num / wsum
      end
    end
  end

  @doc """
  Membership update: `u_ij = 1 / sum_k (d_ij/d_ik)^(2/(m-1))`, with a
  special case when any distance is exactly 0 (hard-assigns membership 1
  to that cluster, 0 elsewhere).
  """
  def update_membership(m, centers, xs) do
    power = 2 / (m - 1)

    Enum.map(xs, fn x ->
      dists = Enum.map(centers, &distance(x, &1))

      case Enum.find_index(dists, &(&1 == 0.0)) do
        nil ->
          Enum.map(dists, fn d_ij ->
            denom = dists |> Enum.map(fn d_ik -> :math.pow(d_ij / d_ik, power) end) |> Enum.sum()
            1.0 / denom
          end)

        zero_idx ->
          for j <- 0..(length(centers) - 1), do: if(j == zero_idx, do: 1.0, else: 0.0)
      end
    end)
  end

  @doc "Euclidean distance between two points."
  def distance(a, b) do
    a
    |> Enum.zip(b)
    |> Enum.map(fn {x, y} -> (x - y) * (x - y) end)
    |> Enum.sum()
    |> :math.sqrt()
  end

  @doc "True when the max absolute cell-wise difference between two membership matrices is below `eps`."
  def converged?(eps, old, new) do
    max_diff =
      old
      |> Enum.zip(new)
      |> Enum.flat_map(fn {orow, nrow} ->
        orow |> Enum.zip(nrow) |> Enum.map(fn {a, b} -> abs(a - b) end)
      end)
      |> Enum.max()

    max_diff < eps
  end

  @doc "Fixed-point loop: recompute centers/membership until convergence or `max_iter`."
  def iterate(%{fuzziness: m, epsilon: eps, max_iter: max_iter}, xs, u0) do
    do_iterate(m, eps, max_iter, xs, u0, 0)
  end

  defp do_iterate(m, eps, max_iter, xs, u, iter) do
    centers = update_centers(m, u, xs)
    new_u = update_membership(m, centers, xs)
    next_iter = iter + 1

    if converged?(eps, u, new_u) or next_iter >= max_iter do
      {centers, new_u, next_iter}
    else
      do_iterate(m, eps, max_iter, xs, new_u, next_iter)
    end
  end
end
