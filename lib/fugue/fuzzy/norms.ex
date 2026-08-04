defmodule Fugue.Fuzzy.Norms do
  @moduledoc """
  T-norms and s-norms, ported from Hazy's `Hazy.Core.TNorm`. Hazy models
  these as two-line typeclass instances (`MinMax`, `Product`, `Lukasiewicz`);
  a plain atom-dispatched function is the right level of abstraction in
  Elixir for three fixed variants, no protocol needed.
  """

  @type kind :: :min_max | :product | :lukasiewicz

  @doc "Fuzzy AND. `:min_max` -> min(a,b), `:product` -> a*b, `:lukasiewicz` -> max(0, a+b-1)."
  def t_norm(:min_max, a, b), do: min(a, b)
  def t_norm(:product, a, b), do: a * b
  def t_norm(:lukasiewicz, a, b), do: max(0.0, a + b - 1)

  @doc "Fuzzy OR. `:min_max` -> max(a,b), `:product` -> a+b-a*b, `:lukasiewicz` -> min(1, a+b)."
  def s_norm(:min_max, a, b), do: max(a, b)
  def s_norm(:product, a, b), do: a + b - a * b
  def s_norm(:lukasiewicz, a, b), do: min(1.0, a + b)
end
