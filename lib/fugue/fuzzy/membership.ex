defmodule Fugue.Fuzzy.Membership do
  @moduledoc """
  Membership function constructors, ported from Hazy's `Hazy.Core.Membership`.
  Each function is curried: it takes the shape parameters and returns a
  `(float -> float)` closure, matching Hazy's `MembershipFn = Double -> Degree`.
  """

  @doc "Triangular membership: 0 outside [a, c], 1 at b, linear ramps on either side."
  def triangular(a, b, c) do
    fn x ->
      cond do
        x <= a -> 0.0
        x >= c -> 0.0
        x < b -> (x - a) / (b - a)
        true -> (c - x) / (c - b)
      end
    end
  end

  @doc "Trapezoidal membership: 0 outside [a, d], 1 on the plateau [b, c], linear ramps between."
  def trapezoidal(a, b, c, d) do
    fn x ->
      cond do
        x <= a -> 0.0
        x >= d -> 0.0
        x >= b and x <= c -> 1.0
        x < b -> (x - a) / (b - a)
        true -> (d - x) / (d - c)
      end
    end
  end

  @doc "Gaussian membership centered at `mu` with standard deviation `sigma`."
  def gaussian(mu, sigma) do
    fn x -> :math.exp(-((x - mu) * (x - mu) / (2 * sigma * sigma))) end
  end

  @doc "Logistic sigmoid membership, transitioning around `center` at the given `slope`."
  def sigmoid(center, slope) do
    fn x -> 1 / (1 + :math.exp(-(slope * (x - center)))) end
  end
end
