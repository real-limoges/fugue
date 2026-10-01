defmodule Fugue.Mood.FuzzifyTest do
  use ExUnit.Case, async: true

  alias Fugue.Mood.Fuzzify

  test "default_membership_func_defs/0 has the 5 canonical input vars and 2 output vars" do
    defs = Fuzzify.default_membership_func_defs()

    assert Enum.map(defs.inputs, & &1.name) == ~w(sleep anxiety sensitivity outlook speed)
    assert Enum.map(defs.outputs, & &1.name) == ~w(wellbeing activation)

    sleep = Enum.find(defs.inputs, &(&1.name == "sleep"))
    assert sleep.bounds == {0, 15}
    assert Enum.map(sleep.terms, & &1.name) == ~w(low medium high)
  end

  test "mood_rules/0 has the 6 hardcoded rules" do
    rules = Fuzzify.mood_rules()
    assert length(rules) == 6

    assert %{
             antecedent: [{"sleep", "high"}, {"anxiety", "low"}],
             consequent: [{"wellbeing", "high"}]
           } =
             Enum.at(rules, 0)

    assert %{antecedent: [{"speed", "low"}], consequent: [{"activation", "low"}]} =
             List.last(rules)
  end

  test "build_mood_fis/1 produces an FIS runnable by Fugue.Fuzzy.Inference.Mamdani" do
    fis = Fuzzify.build_mood_fis(Fuzzify.default_membership_func_defs())

    result =
      Fugue.Fuzzy.Inference.Mamdani.run(fis, %{
        "sleep" => 8.0,
        "anxiety" => 1.0,
        "sensitivity" => 1.0,
        "outlook" => 8.0,
        "speed" => 2.0
      })

    assert is_float(result["wellbeing"])
    assert is_float(result["activation"])
    # Good sleep, low anxiety, high outlook should read as high wellbeing.
    assert result["wellbeing"] > 5.0
  end
end
