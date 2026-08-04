defmodule Fugue.Mood.Fuzzify do
  @moduledoc """
  The mood FIS: default membership-function config, the 6 hardcoded rules,
  and percentile-anchored term suggestion, ported from Ish's
  `Ish.Analysis.Fuzzify`.
  """

  alias Fugue.Fuzzy.Membership

  @doc """
  Canonical default `MembershipFuncDefs`-equivalent config: 5 input vars
  (sleep 0-15, anxiety/sensitivity 0-5, outlook/speed 0-10) and 2 output
  vars (wellbeing/activation, both 0-10), each with low/medium/high
  triangular terms.
  """
  def default_membership_func_defs do
    %{
      inputs: [
        var_def("sleep", {0, 15}, {0, 0, 7.5}, {5, 7.5, 10}, {7.5, 15, 15}),
        var_def("anxiety", {0, 5}, {0, 0, 1}, {0.5, 1.5, 3}, {2, 5, 5}),
        var_def("sensitivity", {0, 5}, {0, 0, 1}, {0.5, 1.5, 3}, {2, 5, 5}),
        var_def("outlook", {0, 10}, {0, 0, 4}, {3, 5, 7}, {6, 10, 10}),
        var_def("speed", {0, 10}, {0, 0, 4}, {3, 5, 7}, {6, 10, 10})
      ],
      outputs: [
        var_def("wellbeing", {0, 10}, {0, 0, 4}, {3, 5, 7}, {6, 10, 10}),
        var_def("activation", {0, 10}, {0, 0, 4}, {3, 5, 7}, {6, 10, 10})
      ]
    }
  end

  @doc "The 6 hardcoded mood rules."
  def mood_rules do
    [
      %{antecedent: [{"sleep", "high"}, {"anxiety", "low"}], consequent: [{"wellbeing", "high"}]},
      %{antecedent: [{"sleep", "low"}, {"anxiety", "high"}], consequent: [{"wellbeing", "low"}]},
      %{antecedent: [{"outlook", "high"}], consequent: [{"wellbeing", "high"}]},
      %{antecedent: [{"outlook", "low"}], consequent: [{"wellbeing", "low"}]},
      %{
        antecedent: [{"speed", "high"}, {"sensitivity", "high"}],
        consequent: [{"activation", "high"}]
      },
      %{antecedent: [{"speed", "low"}], consequent: [{"activation", "low"}]}
    ]
  end

  @doc "Bridge wire-format var defs (as produced by this module) into `Fugue.Fuzzy.Inference.Types.linguistic_var/0`s."
  def build_vars(var_defs) do
    Map.new(var_defs, fn v ->
      {v.name,
       %{
         name: v.name,
         bounds: v.bounds,
         terms:
           Map.new(v.terms, fn t ->
             {a, b, c} = t.params
             {t.name, %{name: t.name, mf: Membership.triangular(a, b, c), universe: v.bounds}}
           end)
       }}
    end)
  end

  @doc "Build a generic FIS from an arbitrary rule set plus membership-function defs."
  def build_fis(rules, defs) do
    %{inputs: build_vars(defs.inputs), outputs: build_vars(defs.outputs), rules: rules}
  end

  @doc "Mood-specific wrapper: always uses `mood_rules/0`."
  def build_mood_fis(defs), do: build_fis(mood_rules(), defs)

  @doc """
  Derive candidate term shapes for each input variable from the present
  values in `rows`. Variable bounds and output-variable definitions are
  preserved unchanged from `current`; terms are rebuilt per-input from
  column percentiles so the fuzzy lens tracks the actual distribution of
  logged values rather than textbook defaults.
  """
  def suggest_membership_func_defs(current, rows) do
    %{
      current
      | inputs:
          Enum.map(current.inputs, fn v ->
            sorted =
              rows
              |> Enum.map(&Map.get(&1, dimension_key(v.name)))
              |> Enum.reject(&is_nil/1)
              |> Enum.sort()

            %{v | terms: suggest_terms(v.bounds, sorted)}
          end)
    }
  end

  defp dimension_key(name), do: String.to_existing_atom(name)

  defp suggest_terms({lo, hi}, []) do
    mid = (lo + hi) / 2

    [
      term_def("low", {lo, lo, mid}),
      term_def("medium", {lo, mid, hi}),
      term_def("high", {mid, hi, hi})
    ]
  end

  defp suggest_terms({lo, hi}, sorted) do
    p17 = percentile(0.17, sorted)
    p33 = percentile(0.33, sorted)
    p50 = percentile(0.50, sorted)
    p67 = percentile(0.67, sorted)
    p83 = percentile(0.83, sorted)

    [
      term_def("low", {lo, lo, p33}),
      term_def("medium", {p17, p50, p83}),
      term_def("high", {p67, hi, hi})
    ]
  end

  # Nearest-rank percentile on an already-sorted, non-empty list.
  defp percentile(p, sorted) do
    n = length(sorted)
    idx = max(0, min(n - 1, trunc(Float.floor(p * (n - 1)))))
    Enum.at(sorted, idx)
  end

  defp var_def(name, bounds, low, medium, high) do
    %{
      name: name,
      bounds: bounds,
      terms: [term_def("low", low), term_def("medium", medium), term_def("high", high)]
    }
  end

  defp term_def(name, params), do: %{name: name, params: params}
end
