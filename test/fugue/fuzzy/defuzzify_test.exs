defmodule Fugue.Fuzzy.DefuzzifyTest do
  use ExUnit.Case, async: true

  alias Fugue.Fuzzy.{Defuzzify, Membership}

  setup do
    symmetric = %{
      name: "symmetric",
      mf: Membership.triangular(0.0, 5.0, 10.0),
      universe: {0.0, 10.0}
    }

    %{pairs: [{symmetric, 1.0}]}
  end

  test "defuzzify/2 with no firing consequents returns 0.0" do
    assert Defuzzify.defuzzify(:centroid, []) == 0.0
  end

  test "centroid of a symmetric triangle lands on its peak", %{pairs: pairs} do
    assert_in_delta Defuzzify.defuzzify(:centroid, pairs), 5.0, 0.1
  end

  test "bisector of a symmetric triangle lands on its peak", %{pairs: pairs} do
    assert_in_delta Defuzzify.defuzzify(:bisector, pairs), 5.0, 0.1
  end

  test "smallest_of_max, largest_of_max, and mean_of_maximum all land near the peak", %{
    pairs: pairs
  } do
    assert_in_delta Defuzzify.defuzzify(:smallest_of_max, pairs), 5.0, 0.1
    assert_in_delta Defuzzify.defuzzify(:largest_of_max, pairs), 5.0, 0.1
    assert_in_delta Defuzzify.defuzzify(:mean_of_maximum, pairs), 5.0, 0.1
  end

  test "custom method delegates to the given function", %{pairs: pairs} do
    assert Defuzzify.defuzzify({:custom, fn _pairs -> 42.0 end}, pairs) == 42.0
  end

  test "sampled_aggregation/1 returns [] for no consequents and 200 points otherwise", %{
    pairs: pairs
  } do
    assert Defuzzify.sampled_aggregation([]) == []
    assert length(Defuzzify.sampled_aggregation(pairs)) == 200
  end
end
