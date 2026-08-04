defmodule Fugue.Fuzzy.OperatorsTest do
  use ExUnit.Case, async: true

  alias Fugue.Fuzzy.{Membership, Operators}

  setup do
    low = %{name: "low", mf: Membership.triangular(0.0, 0.0, 10.0), universe: {0.0, 20.0}}
    high = %{name: "high", mf: Membership.triangular(0.0, 20.0, 20.0), universe: {-5.0, 25.0}}
    %{low: low, high: high}
  end

  test "fuzzy_and narrows the universe to the overlap and applies the t-norm", %{
    low: low,
    high: high
  } do
    combined = Operators.fuzzy_and(:min_max, low, high)
    assert combined.universe == {0.0, 20.0}
    assert combined.mf.(5.0) == min(low.mf.(5.0), high.mf.(5.0))
  end

  test "fuzzy_or narrows the universe to the overlap and applies the s-norm", %{
    low: low,
    high: high
  } do
    combined = Operators.fuzzy_or(:min_max, low, high)
    assert combined.universe == {0.0, 20.0}
    assert combined.mf.(5.0) == max(low.mf.(5.0), high.mf.(5.0))
  end

  test "fuzzy_not complements membership", %{low: low} do
    negated = Operators.fuzzy_not(low)
    assert_in_delta negated.mf.(5.0), 1 - low.mf.(5.0), 1.0e-9
  end

  test "very squares membership", %{low: low} do
    concentrated = Operators.very(low)
    assert_in_delta concentrated.mf.(5.0), :math.pow(low.mf.(5.0), 2), 1.0e-9
  end

  test "somewhat square-roots membership", %{low: low} do
    diluted = Operators.somewhat(low)
    assert_in_delta diluted.mf.(5.0), :math.sqrt(low.mf.(5.0)), 1.0e-9
  end
end
