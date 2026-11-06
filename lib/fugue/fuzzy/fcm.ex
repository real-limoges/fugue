defmodule Fugue.Fuzzy.FCM do
  @moduledoc """
  Fuzzy C-Means clustering, ported from Hazy's `Hazy.Algorithms.FCM` and
  `Hazy.Algorithms.FCM.Internal`. Points and centers are plain lists of
  floats; membership matrices are lists of rows (one row per point, one
  column per cluster).
  """

  @typedoc "A point or a center: one float per dimension."
  @type point :: [float()]

  @typedoc "Rows are points, columns are clusters; each row sums to 1."
  @type membership :: [[float()]]

  @type config :: %{
          clusters: pos_integer(),
          fuzziness: float(),
          epsilon: float(),
          max_iter: pos_integer()
        }

  @type result :: %{centers: [point()], membership: membership(), iterations: pos_integer()}

  @doc "Default config: `fuzziness: 2.0, epsilon: 1e-5, max_iter: 100`."
  @spec default_config(pos_integer()) :: config()
  def default_config(clusters) do
    %{clusters: clusters, fuzziness: 2.0, epsilon: 1.0e-5, max_iter: 100}
  end

  @doc "Run FCM on `xs` (a non-empty list of points). Returns `%{centers:, membership:, iterations:}`."
  @spec run(config(), [point(), ...]) :: result()
  def run(config, xs) do
    u0 = init_membership(length(xs), config.clusters)
    {centers, membership, iterations} = iterate(config, xs, u0)
    %{centers: centers, membership: membership, iterations: iterations}
  end

  @doc """
  Deterministic pseudo-seeding, row-normalized so each point's membership
  across clusters sums to 1. It is not true randomness, and must not become
  it: reproducible tests depend on it.
  """
  @spec init_membership(non_neg_integer(), pos_integer()) :: membership()
  def init_membership(n, c) do
    # `//1`: without an explicit step, `0..(n - 1)` with n = 0 counts down
    # through 0 and -1 and seeds two rows for zero points.
    for i <- 0..(n - 1)//1 do
      raw = for j <- 0..(c - 1)//1, do: 1.0 + 0.1 * :math.sin(i * 7 + j * 13)
      total = Enum.sum(raw)
      Enum.map(raw, &(&1 / total))
    end
  end

  @doc "Weighted centroid update: `center_j[dim] = sum_i(u_ij^m * x_i[dim]) / sum_i(u_ij^m)`."
  @spec update_centers(float(), membership(), [point(), ...]) :: [point()]
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
  @spec update_membership(float(), [point()], [point()]) :: membership()
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
  @spec distance(point(), point()) :: float()
  def distance(a, b) do
    a
    |> Enum.zip(b)
    |> Enum.map(fn {x, y} -> (x - y) * (x - y) end)
    |> Enum.sum()
    |> :math.sqrt()
  end

  @doc "True when the max absolute cell-wise difference between two membership matrices is below `eps`."
  @spec converged?(float(), membership(), membership()) :: boolean()
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
  @spec iterate(config(), [point(), ...], membership()) ::
          {[point()], membership(), pos_integer()}
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
