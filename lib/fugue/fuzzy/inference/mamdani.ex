defmodule Fugue.Fuzzy.Inference.Mamdani do
  @moduledoc """
  Mamdani fuzzy inference, ported from Hazy's `Hazy.Inference.Mamdani`.
  Fuzzify -> rule evaluation -> consequent clipping -> aggregation -> defuzzify.

  Hazy also has a Sugeno inference path (`Hazy.Inference.Sugeno`) reached
  through a single `evaluate` dispatcher, but Ish always hardcodes the
  Mamdani method -- Sugeno has zero real callers. It's not ported here;
  this module is called directly wherever Hazy's `evaluate` would have
  been. Add a Sugeno port later if a real need shows up.

  See `Fugue.Fuzzy.Inference.Types` for the shapes of `fis` and `inputs`.
  """

  alias Fugue.Fuzzy.Defuzzify

  @doc "Fuzzify -> infer -> defuzzify (centroid). Returns `%{output_var => crisp_value}`."
  def run(fis, inputs) do
    fis.rules
    |> Enum.map(&eval_rule(fis, inputs, &1))
    |> List.flatten()
    |> group_consequents()
    |> Map.new(fn {out_var, pairs} -> {out_var, Defuzzify.defuzzify(:centroid, pairs)} end)
  end

  @doc """
  Same pipeline as `run/2`, but retains the intermediate state (fuzzified
  inputs, per-rule firing strengths, per-output-var aggregated curves, and
  crisp outputs) that UI callers use for visualization.
  """
  def trace(fis, inputs) do
    grouped =
      fis.rules
      |> Enum.map(&eval_rule(fis, inputs, &1))
      |> List.flatten()
      |> group_consequents()

    %{
      input_degrees: input_degrees_at(fis, inputs),
      rule_strengths: Enum.map(fis.rules, &firing_strength(fis, inputs, &1.antecedent)),
      output_curves:
        Map.new(grouped, fn {k, pairs} -> {k, Defuzzify.sampled_aggregation(pairs)} end),
      crisp: Map.new(grouped, fn {k, pairs} -> {k, Defuzzify.defuzzify(:centroid, pairs)} end)
    }
  end

  defp input_degrees_at(fis, inputs) do
    for {var_name, lv} <- fis.inputs,
        crisp = Map.get(inputs, var_name),
        not is_nil(crisp),
        into: %{} do
      {var_name, Map.new(lv.terms, fn {term_name, fs} -> {term_name, fs.mf.(crisp)} end)}
    end
  end

  defp eval_rule(fis, inputs, rule) do
    alpha = firing_strength(fis, inputs, rule.antecedent)

    for {out_var, term_name} <- rule.consequent,
        lv = Map.get(fis.outputs, out_var),
        not is_nil(lv),
        fs = Map.get(lv.terms, term_name),
        not is_nil(fs) do
      {out_var, fs, alpha}
    end
  end

  # Antecedent firing strength via min t-norm.
  defp firing_strength(fis, inputs, antecedents) do
    case antecedents |> Enum.map(&eval_antecedent(fis, inputs, &1)) |> Enum.reject(&is_nil/1) do
      [] -> 0.0
      degrees -> Enum.min(degrees)
    end
  end

  defp eval_antecedent(fis, inputs, {var_name, term_name}) do
    with lv when not is_nil(lv) <- Map.get(fis.inputs, var_name),
         fs when not is_nil(fs) <- Map.get(lv.terms, term_name),
         crisp when not is_nil(crisp) <- Map.get(inputs, var_name) do
      fs.mf.(crisp)
    else
      _ -> nil
    end
  end

  defp group_consequents(triples) do
    Enum.reduce(triples, %{}, fn {out_var, fs, alpha}, acc ->
      Map.update(acc, out_var, [{fs, alpha}], &[{fs, alpha} | &1])
    end)
  end
end
