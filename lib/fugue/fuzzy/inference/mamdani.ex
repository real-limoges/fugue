defmodule Fugue.Fuzzy.Inference.Mamdani do
  @moduledoc """
  Mamdani fuzzy inference, ported from Hazy's `Hazy.Inference.Mamdani`.
  Fuzzify -> rule evaluation -> consequent clipping -> aggregation -> defuzzify.

  Hazy also has a Sugeno inference path (`Hazy.Inference.Sugeno`) reached
  through a single `evaluate` dispatcher, but Ish always hardcodes the
  Mamdani method, so Sugeno has no real callers. It's not ported here;
  this module is called directly wherever Hazy's `evaluate` would have
  been. Add a Sugeno port later if a real need shows up.

  Every lookup is strict: a rule naming a variable or term the FIS lacks,
  or inputs missing one of the FIS's input variables, raises. A rule needs
  at least one antecedent; `Fugue.Fuzzy.Inference.Wire` refuses an empty
  one by name. Hazy skipped
  those quietly, which turned a typo in a rule into a rule that never
  fires.

  See `Fugue.Fuzzy.Inference.Types` for the shapes of `fis` and `inputs`.
  """

  alias Fugue.Fuzzy.Defuzzify
  alias Fugue.Fuzzy.Inference.Types

  @doc "Fuzzify -> infer -> defuzzify (centroid). Returns `%{output_var => crisp_value}`."
  @spec run(Types.fis(), Types.crisp_inputs()) :: %{String.t() => float()}
  def run(fis, inputs) do
    fis |> consequents(inputs) |> Map.new(fn {k, pairs} -> {k, Defuzzify.centroid(pairs)} end)
  end

  @doc """
  Same pipeline as `run/2`, but retains the intermediate state (fuzzified
  inputs, per-rule firing strengths, per-output-var aggregated curves, and
  crisp outputs) that UI callers use for visualization.
  """
  @spec trace(Types.fis(), Types.crisp_inputs()) :: Types.inference_trace()
  def trace(fis, inputs) do
    grouped = consequents(fis, inputs)

    %{
      input_degrees: input_degrees(fis, inputs),
      rule_strengths: Enum.map(fis.rules, &firing_strength(fis, inputs, &1.antecedent)),
      output_curves:
        Map.new(grouped, fn {k, pairs} -> {k, Defuzzify.sampled_aggregation(pairs)} end),
      crisp: Map.new(grouped, fn {k, pairs} -> {k, Defuzzify.centroid(pairs)} end)
    }
  end

  # Every rule's clipped consequents, grouped by output variable.
  defp consequents(fis, inputs) do
    fis.rules
    |> Enum.flat_map(&eval_rule(fis, inputs, &1))
    |> Enum.group_by(fn {out_var, _fs, _alpha} -> out_var end, fn {_, fs, alpha} ->
      {fs, alpha}
    end)
  end

  defp input_degrees(fis, inputs) do
    Map.new(fis.inputs, fn {var_name, lv} ->
      crisp = Map.fetch!(inputs, var_name)
      {var_name, Map.new(lv.terms, fn {term_name, fs} -> {term_name, fs.mf.(crisp)} end)}
    end)
  end

  defp eval_rule(fis, inputs, rule) do
    alpha = firing_strength(fis, inputs, rule.antecedent)

    for {out_var, term_name} <- rule.consequent do
      {out_var, term(fis.outputs, out_var, term_name), alpha}
    end
  end

  # Antecedent firing strength via min t-norm.
  defp firing_strength(fis, inputs, antecedents) do
    antecedents
    |> Enum.map(fn {var_name, term_name} ->
      term(fis.inputs, var_name, term_name).mf.(Map.fetch!(inputs, var_name))
    end)
    |> Enum.min()
  end

  defp term(vars, var_name, term_name) do
    vars |> Map.fetch!(var_name) |> Map.fetch!(:terms) |> Map.fetch!(term_name)
  end
end
