defmodule Fugue.Lab.Bayes do
  @moduledoc """
  The math behind `/lab/bayes`, kept out of the LiveView so it can be
  tested on its own. Every function is pure except `poisson_sample/1`,
  which draws from `:rand`.

  - Search: a belief grid over cells, as a flat row-major list of
    probabilities summing to 1. A miss in a cell zeroes it and spreads its
    mass over the rest.
  - Rate: a Gamma prior on a Poisson rate. Gamma is conjugate to Poisson,
    so observing events updates the prior's parameters in closed form.
  """

  @doc """
  A `rows` x `cols` belief grid shaped like a Gaussian bump centered on
  `{peak_row, peak_col}`, normalized to sum to 1.
  """
  def search_prior(rows, cols, {peak_row, peak_col}, sigma) do
    raw =
      for r <- 0..(rows - 1), c <- 0..(cols - 1) do
        d2 = (r - peak_row) ** 2 + (c - peak_col) ** 2
        :math.exp(-d2 / (2.0 * sigma * sigma))
      end

    normalize(raw)
  end

  @doc """
  The belief after searching cell `i` and finding nothing there: that cell
  drops to 0 and the rest are rescaled to sum to 1. A grid with no mass
  left stays all zeros.
  """
  def search_miss(grid, i) do
    zeroed = List.replace_at(grid, i, 0.0)
    if Enum.sum(zeroed) <= 0, do: zeroed, else: normalize(zeroed)
  end

  @doc """
  The Gamma posterior `{alpha, beta}` after seeing `count` events over
  `years` years, starting from the Gamma prior `{alpha, beta}`.
  """
  def rate_posterior({alpha, beta}, count, years), do: {alpha + count, beta + years}

  @doc """
  One draw from a Poisson distribution with the given mean, by Knuth's
  algorithm. Its running time grows with the mean, which is fine for the
  small means the page uses (up to about 20).
  """
  def poisson_sample(mean), do: poisson_step(:math.exp(-mean), 1.0, 0)

  defp poisson_step(limit, p, k) do
    p = p * :rand.uniform()
    if p <= limit, do: k, else: poisson_step(limit, p, k + 1)
  end

  defp normalize(weights) do
    total = Enum.sum(weights)
    Enum.map(weights, &(&1 / total))
  end
end
