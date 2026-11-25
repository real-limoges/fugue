defmodule Fugue.Fuzzy.DefuzzifyTest do
  use ExUnit.Case, async: true

  alias Fugue.Fuzzy.{Defuzzify, Membership}

  setup do
    symmetric = %{
      name: "symmetric",
      mf: Membership.triangular(0.0, 5.0, 10.0),
      universe: {0.0, 10.0}
    }

    %{pairs: [{symmetric, 1.0}], symmetric: symmetric}
  end

  test "centroid/1 with no firing consequents returns 0.0" do
    assert Defuzzify.centroid([]) == 0.0
  end

  test "centroid of a symmetric triangle lands on its peak", %{pairs: pairs} do
    assert_in_delta Defuzzify.centroid(pairs), 5.0, 0.1
  end

  test "a consequent clipped to zero has its universe's middle as centroid", %{
    symmetric: symmetric
  } do
    assert Defuzzify.centroid([{%{symmetric | universe: {0.0, 4.0}}, 0.0}]) == 2.0
  end

  test "sampled_aggregation/1 returns [] for no consequents and 200 points otherwise", %{
    pairs: pairs
  } do
    assert Defuzzify.sampled_aggregation([]) == []
    assert length(Defuzzify.sampled_aggregation(pairs)) == 200
  end
end
