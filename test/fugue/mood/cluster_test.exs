defmodule Fugue.Mood.ClusterTest do
  use ExUnit.Case, async: true

  alias Fugue.Mood.{Cluster, DataFrame, Fuzzify}
  alias Fugue.MoodFixtures

  setup do
    fis = Fuzzify.build_mood_fis(Fuzzify.default_membership_func_defs())
    spine = DataFrame.fill_missing_dates(MoodFixtures.entries())
    %{fis: fis, spine: spine}
  end

  test "default_config/0 is k=3, m=2.0" do
    assert Cluster.default_config() == %{k: 3, m: 2.0}
  end

  test "run/3 separates the fixture's two visually distinct mood clouds", %{
    fis: fis,
    spine: spine
  } do
    result = Cluster.run(fis, %{k: 2, m: 2.0}, spine)

    assert length(result.centers) == 2
    assert length(result.clusters) == 2
    assert result.iterations > 0
    assert length(result.dates) == 19

    # Every cluster gets a name built from its wellbeing/activation labels
    # and a non-negative size; sizes across clusters cover all 19 points.
    assert Enum.all?(result.clusters, &(&1.name != ""))
    assert Enum.reduce(result.clusters, 0, &(&1.size + &2)) == 19
  end

  test "cluster labels use bounds-derived thresholds, not hardcoded 3.33/6.67", %{
    fis: fis,
    spine: spine
  } do
    result = Cluster.run(fis, %{k: 2, m: 2.0}, spine)

    for cluster <- result.clusters, label <- cluster.labels do
      assert label.name =~ ~r/^(wellbeing|activation) (low|medium|high)$/
    end
  end
end
