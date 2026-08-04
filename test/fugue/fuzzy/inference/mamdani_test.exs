defmodule Fugue.Fuzzy.Inference.MamdaniTest do
  use ExUnit.Case, async: true

  alias Fugue.Fuzzy.Inference.Mamdani
  alias Fugue.Fuzzy.Membership

  # Terms deliberately avoid a==b or b==c: Hazy's (and this port's) triangular
  # membership function returns 0 at x<=a, even when a==b, so a degenerate
  # "low" term like triangular(0,0,10) would evaluate to 0 at its own peak.
  # Mirror-image shapes (each spanning the full [lo, hi] domain, peaks at the
  # opposite ends) keep the test's midpoint symmetric.
  setup do
    term = fn name, mf -> %{name: name, mf: mf, universe: {0.0, 10.0}} end

    fis = %{
      inputs: %{
        "temp" => %{
          name: "temp",
          bounds: {0.0, 10.0},
          terms: %{
            "low" => term.("low", Membership.triangular(-10.0, 0.0, 10.0)),
            "high" => term.("high", Membership.triangular(0.0, 10.0, 20.0))
          }
        }
      },
      outputs: %{
        "fan" => %{
          name: "fan",
          bounds: {0.0, 10.0},
          terms: %{
            "off" => term.("off", Membership.triangular(-10.0, 0.0, 10.0)),
            "on" => term.("on", Membership.triangular(0.0, 10.0, 20.0))
          }
        }
      },
      rules: [
        %{antecedent: [{"temp", "low"}], consequent: [{"fan", "off"}]},
        %{antecedent: [{"temp", "high"}], consequent: [{"fan", "on"}]}
      ]
    }

    %{fis: fis}
  end

  test "cold input drives the output toward the off consequent", %{fis: fis} do
    cold = Mamdani.run(fis, %{"temp" => 0.0})
    midpoint = Mamdani.run(fis, %{"temp" => 5.0})
    assert cold["fan"] < midpoint["fan"]
    # Only "off" fires at temp=0, so the crisp value is that term's own
    # centroid (a full-width linear ramp -> 1/3 of the way across, not 0).
    assert_in_delta cold["fan"], 10 / 3, 0.5
  end

  test "hot input drives the output toward the on consequent", %{fis: fis} do
    hot = Mamdani.run(fis, %{"temp" => 10.0})
    midpoint = Mamdani.run(fis, %{"temp" => 5.0})
    assert hot["fan"] > midpoint["fan"]
    assert_in_delta hot["fan"], 20 / 3, 0.5
  end

  test "midpoint input balances both rules symmetrically", %{fis: fis} do
    result = Mamdani.run(fis, %{"temp" => 5.0})
    assert_in_delta result["fan"], 5.0, 0.1
  end

  test "trace/2 exposes the full intermediate pipeline", %{fis: fis} do
    trace = Mamdani.trace(fis, %{"temp" => 5.0})

    assert Map.has_key?(trace.input_degrees, "temp")
    assert length(trace.rule_strengths) == 2
    assert Map.has_key?(trace.output_curves, "fan")
    assert length(trace.output_curves["fan"]) == 200
    assert_in_delta trace.crisp["fan"], 5.0, 0.1
  end
end
