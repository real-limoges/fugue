defmodule Fugue.Fuzzy.Membership do
  @moduledoc """
  Membership function constructors, ported from Hazy's `Hazy.Core.Membership`.
  Each function is curried: it takes the shape parameters and returns a
  `(float -> float)` closure, matching Hazy's `MembershipFn = Double -> Degree`.

  Only the triangle is used. Hazy's trapezoid, Gaussian and sigmoid, and its
  `Operators` and `Norms` modules, were deleted on 2026-11-25 for having no
  callers.
  """

  alias Fugue.Fuzzy.Inference.Types

  @doc """
  Triangular membership: 0 outside [a, c], 1 at b, linear ramps on either
  side. A shoulder (`a == b` or `b == c`) is 1 at its peak, so a term like
  `cold [0, 0, 26]` is fully cold at 0. The peak is checked first because
  at a shoulder it is also an endpoint; Hazy checked the endpoints first
  and scored such a peak 0.
  """
  @spec triangular(number(), number(), number()) :: Types.mf()
  def triangular(a, b, c) do
    fn x ->
      cond do
        x == b -> 1.0
        x <= a or x >= c -> 0.0
        x < b -> (x - a) / (b - a)
        true -> (c - x) / (c - b)
      end
    end
  end

  @doc """
  A linguistic variable whose terms are all triangles. `terms` pairs each
  term name with its `{a, b, c}`; every term's universe is the variable's
  bounds.
  """
  @spec triangular_var(String.t(), {number(), number()}, [
          {String.t(), {number(), number(), number()}}
        ]) ::
          Types.linguistic_var()
  def triangular_var(name, bounds, terms) do
    %{
      name: name,
      bounds: bounds,
      terms:
        Map.new(terms, fn {term_name, {a, b, c}} ->
          {term_name, %{name: term_name, mf: triangular(a, b, c), universe: bounds}}
        end)
    }
  end
end
