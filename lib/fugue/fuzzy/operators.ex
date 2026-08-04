defmodule Fugue.Fuzzy.Operators do
  @moduledoc """
  Fuzzy-set combinators, ported from Hazy's `Hazy.Core.Operators`. A fuzzy
  set here is a plain map `%{name: String.t(), mf: (float -> float),
  universe: {float, float}}`, matching Hazy's `FuzzySet` record.
  """

  alias Fugue.Fuzzy.Norms

  @doc "Intersect two fuzzy sets via a t-norm; universe narrows to the overlap."
  def fuzzy_and(norm, a, b) do
    {lo1, hi1} = a.universe
    {lo2, hi2} = b.universe

    %{
      name: a.name <> "__AND__" <> b.name,
      mf: fn x -> Norms.t_norm(norm, a.mf.(x), b.mf.(x)) end,
      universe: {max(lo1, lo2), min(hi1, hi2)}
    }
  end

  @doc "Union two fuzzy sets via an s-norm; universe narrows to the overlap."
  def fuzzy_or(norm, a, b) do
    {lo1, hi1} = a.universe
    {lo2, hi2} = b.universe

    %{
      name: a.name <> "__OR__" <> b.name,
      mf: fn x -> Norms.s_norm(norm, a.mf.(x), b.mf.(x)) end,
      universe: {max(lo1, lo2), min(hi1, hi2)}
    }
  end

  @doc "Complement: 1 - membership."
  def fuzzy_not(fs), do: %{fs | mf: fn x -> 1 - fs.mf.(x) end}

  @doc "Concentration hedge: membership squared."
  def very(fs), do: %{fs | mf: fn x -> :math.pow(fs.mf.(x), 2) end}

  @doc "Dilation hedge: square root of membership."
  def somewhat(fs), do: %{fs | mf: fn x -> :math.sqrt(fs.mf.(x)) end}
end
