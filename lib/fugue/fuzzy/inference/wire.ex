defmodule Fugue.Fuzzy.Inference.Wire do
  @moduledoc """
  Wire-format adapter for Mamdani inference, ported from Ish's
  `Ish.Analysis.Mamdani`. Decodes the `%{"mfs" => ..., "rules" => ...,
  "values" => ...}` shape (what Ish's `POST /inference/mamdani` accepted,
  and what `Fugue.Menagerie.Mamdani.request/2` already builds for the fan
  demo), runs a Mamdani trace, and re-encodes to the wire response shape.

  Deliberately generic, not mood-specific: the menagerie fan-speed demo
  exercises this exact same contract with unrelated temperature/humidity/
  fan-speed variables, so it belongs alongside the rest of the fuzzy
  library rather than under the mood-specific modules.
  """

  alias Fugue.Fuzzy.Inference.Mamdani
  alias Fugue.Fuzzy.Membership

  @doc """
  Run a wire-format Mamdani request (string-keyed map, matching the JSON
  shape) and return a wire-format response: `%{"input_degrees" => ...,
  "rule_strengths" => ..., "output_curves" => %{var => [[x, y], ...]},
  "crisp" => ...}`.
  """
  def run_request(%{"mfs" => mfs, "rules" => rules, "values" => values}) do
    fis = build_fis(mfs, rules)
    trace = Mamdani.trace(fis, values)
    encode_response(trace)
  end

  @doc "Decode a wire-format `mfs`/`rules` pair into an FIS."
  def build_fis(%{"inputs" => inputs, "outputs" => outputs}, rules) do
    %{
      inputs: Map.new(inputs, &{&1["name"], decode_var(&1)}),
      outputs: Map.new(outputs, &{&1["name"], decode_var(&1)}),
      rules: Enum.map(rules, &decode_rule/1)
    }
  end

  defp decode_var(%{"name" => name, "bounds" => [lo, hi], "terms" => terms}) do
    %{
      name: name,
      bounds: {lo, hi},
      terms: Map.new(terms, &decode_term(&1, {lo, hi}))
    }
  end

  defp decode_term(%{"name" => name, "params" => [a, b, c]}, universe) do
    {name, %{name: name, mf: Membership.triangular(a, b, c), universe: universe}}
  end

  defp decode_rule(%{"if" => antecedent, "then" => consequent}) do
    %{
      antecedent: Enum.map(antecedent, &{&1["var"], &1["term"]}),
      consequent: Enum.map(consequent, &{&1["var"], &1["term"]})
    }
  end

  defp encode_response(trace) do
    %{
      "input_degrees" => trace.input_degrees,
      "rule_strengths" => trace.rule_strengths,
      "output_curves" =>
        Map.new(trace.output_curves, fn {var, points} ->
          {var, Enum.map(points, fn {x, y} -> [x, y] end)}
        end),
      "crisp" => trace.crisp
    }
  end
end
