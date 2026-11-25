defmodule Fugue.Menagerie.QuantumStats do
  @moduledoc """
  Occupation of 30 energy levels (`e_i = i`) under Maxwell-Boltzmann,
  Bose-Einstein and Fermi-Dirac statistics, for the `/menagerie/quantum-stats`
  figure.

  For N particles at temperature kT, each statistics gets the chemical
  potential mu that makes its occupations sum to N. Maxwell-Boltzmann has a
  closed form. Bose-Einstein and Fermi-Dirac are solved by bisection, which
  works because the sum rises monotonically with mu.

  Ported from the former `QuantumStats` canvas hook.
  """

  @levels 30
  @bisection_steps 120

  # :math.exp raises past about 709, where JS would return Infinity. The
  # bisection's low bound at low temperature asks for exponents in the
  # thousands, so every exponent goes through `exp/1`, which caps it. At
  # the cap the occupation it feeds is ~1e-304, which is zero on the chart.
  @max_exponent 700.0

  @type statistics :: :mb | :be | :fd

  @doc "The number of energy levels."
  @spec levels() :: pos_integer()
  def levels, do: @levels

  @doc "Occupation of each level for all three statistics at kT `t` with `n` particles."
  @spec curves(float(), pos_integer()) :: %{statistics() => [float()]}
  def curves(t, n) do
    Map.new([:mb, :be, :fd], fn kind -> {kind, occupation(kind, t, solve_mu(kind, t, n))} end)
  end

  @doc "The chemical potential at which `kind`'s occupations sum to `n`."
  @spec solve_mu(statistics(), float(), pos_integer()) :: float()
  def solve_mu(:mb, t, n) do
    z = energies() |> Enum.map(&exp(-&1 / t)) |> Enum.sum()
    t * :math.log(n / z)
  end

  def solve_mu(kind, t, n) when kind in [:be, :fd] do
    {lo, hi} = bracket(kind, t)

    {lo, hi} =
      Enum.reduce(1..@bisection_steps, {lo, hi}, fn _, {lo, hi} ->
        mid = (lo + hi) / 2
        if total(kind, t, mid) > n, do: {lo, mid}, else: {mid, hi}
      end)

    (lo + hi) / 2
  end

  @doc "The occupation of each level under `kind` at kT `t` and chemical potential `mu`."
  @spec occupation(statistics(), float(), float()) :: [float()]
  def occupation(kind, t, mu), do: Enum.map(energies(), &level(kind, (&1 - mu) / t))

  # Bose-Einstein's mu must stay strictly below the ground state, close
  # enough that a condensate still resolves at very low temperature.
  defp bracket(:be, t), do: {-200.0 * max(t, 1.0), -1.0e-12}
  defp bracket(:fd, t), do: {-200.0 * max(t, 1.0), @levels - 1 + 200.0 * max(t, 1.0)}

  defp total(kind, t, mu), do: kind |> occupation(t, mu) |> Enum.sum()

  defp level(:mb, x), do: exp(-x)
  # x > 0 for every level while mu stays below the ground state, so the
  # denominator is positive; the floor only keeps a rounding to 0.0 from
  # dividing by zero.
  defp level(:be, x), do: 1.0 / max(exp(x) - 1.0, 1.0e-300)
  defp level(:fd, x), do: 1.0 / (exp(x) + 1.0)

  defp exp(x), do: :math.exp(min(x, @max_exponent))

  defp energies, do: Enum.map(0..(@levels - 1), &(&1 * 1.0))
end
