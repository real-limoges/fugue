defmodule Fugue.Fuzzy.Inference.Types do
  @moduledoc """
  Shape reference for the plain maps passed around `Fugue.Fuzzy.Inference.*`,
  ported from Hazy's `Hazy.Inference.Types`. These are documentation-only
  typespecs, not structs; this codebase favors plain maps for wire-shaped
  data (see `Fugue.Menagerie.Mamdani`, `Fugue.Menagerie.Fuzzy`).

  - `fuzzy_set`: `%{name: String.t(), mf: (float -> float), universe: {float, float}}`
  - `linguistic_var`: `%{name: String.t(), terms: %{String.t() => fuzzy_set}, bounds: {float, float}}`
  - `fuzzy_rule`: `%{antecedent: [{String.t(), String.t()}], consequent: [{String.t(), String.t()}]}`
    (var/term pairs; antecedents are ANDed via min t-norm)
  - `fis`: `%{inputs: %{String.t() => linguistic_var}, outputs: %{String.t() => linguistic_var}, rules: [fuzzy_rule]}`
    (method is always Mamdani -- see the Sugeno note in `Fugue.Fuzzy.Inference.Mamdani`)
  - `inference_trace`: `%{input_degrees: map(), rule_strengths: [float()], output_curves: map(), crisp: map()}`
  """

  @type fuzzy_set :: %{name: String.t(), mf: (float() -> float()), universe: {float(), float()}}
  @type linguistic_var :: %{
          name: String.t(),
          terms: %{String.t() => fuzzy_set()},
          bounds: {float(), float()}
        }
  @type fuzzy_rule :: %{
          antecedent: [{String.t(), String.t()}],
          consequent: [{String.t(), String.t()}]
        }
  @type fis :: %{
          inputs: %{String.t() => linguistic_var()},
          outputs: %{String.t() => linguistic_var()},
          rules: [fuzzy_rule()]
        }
  @type inference_trace :: %{
          input_degrees: %{String.t() => %{String.t() => float()}},
          rule_strengths: [float()],
          output_curves: %{String.t() => [{float(), float()}]},
          crisp: %{String.t() => float()}
        }
end
