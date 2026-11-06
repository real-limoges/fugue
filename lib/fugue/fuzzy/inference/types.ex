defmodule Fugue.Fuzzy.Inference.Types do
  @moduledoc """
  Types for the plain maps passed around `Fugue.Fuzzy.*`, ported from
  Hazy's `Hazy.Inference.Types`. They stay maps rather than structs: this
  codebase favors plain maps for wire-shaped data (see
  `Fugue.Menagerie.Mamdani`, `Fugue.Menagerie.Fuzzy`). Dialyzer checks
  every spec that names them.

  - `fuzzy_set`: a named membership function over a universe
  - `linguistic_var`: a variable's terms (`"low"`, `"medium"`, ...) and bounds
  - `fuzzy_rule`: var/term pairs; antecedents are ANDed via the min t-norm
  - `fis`: inputs, outputs and rules (the method is always Mamdani; see the
    Sugeno note in `Fugue.Fuzzy.Inference.Mamdani`)
  - `inference_trace`: the intermediate state a UI draws

  Bounds and universes are `number()`, not `float()`: the mood FIS
  (`Fugue.Mood.Fuzzify`) writes them as integer pairs like `{0, 15}`.
  """

  @typedoc "A membership degree. Nominally in [0, 1]."
  @type degree :: float()

  @typedoc "A membership function: crisp value in, degree out."
  @type mf :: (number() -> degree())

  @type fuzzy_set :: %{name: String.t(), mf: mf(), universe: {number(), number()}}
  @type linguistic_var :: %{
          name: String.t(),
          terms: %{String.t() => fuzzy_set()},
          bounds: {number(), number()}
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

  @typedoc "Crisp input values keyed by input variable name."
  @type crisp_inputs :: %{String.t() => number()}

  @typedoc "A sampled curve: `{x, degree}` points in ascending x."
  @type curve :: [{float(), degree()}]

  @type inference_trace :: %{
          input_degrees: %{String.t() => %{String.t() => degree()}},
          rule_strengths: [degree()],
          output_curves: %{String.t() => curve()},
          crisp: %{String.t() => float()}
        }
end
