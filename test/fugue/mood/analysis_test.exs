defmodule Fugue.Mood.AnalysisTest do
  use ExUnit.Case, async: true

  alias Fugue.Mood.{Analysis, DataFrame, Fuzzify}
  alias Fugue.MoodFixtures

  setup do
    fis = Fuzzify.build_mood_fis(Fuzzify.default_membership_func_defs())
    spine = DataFrame.fill_missing_dates(MoodFixtures.entries())
    %{fis: fis, spine: spine}
  end

  test "analyze/3 returns clusters and a weighted, deduped summary", %{fis: fis, spine: spine} do
    result = Analysis.analyze(fis, spine, %{k: 2, m: 2.0})

    assert %{clusters: clusters, summary: summary} = result
    assert length(clusters) == 2

    # Summary is deduped by label name (max, not sum, across clusters) so
    # there's at most one entry per distinct "wellbeing high"-style name.
    names = Enum.map(summary, & &1.name)
    assert names == Enum.uniq(names)

    # "membership" here is the crisp wellbeing/activation output (0-10
    # scale) weighted by cluster-size fraction (0-1) -- ported directly
    # from Ish, where the field is a defuzzified value, not a [0,1] degree.
    assert Enum.all?(summary, &(&1.membership >= 0.0 and &1.membership <= 10.0))
  end

  test "analyze/3 defaults to k=3, m=2.0 when no config is given", %{fis: fis, spine: spine} do
    result = Analysis.analyze(fis, spine)
    assert length(result.clusters) == 3
  end

  test "cluster_entries/3 returns just the cluster list", %{fis: fis, spine: spine} do
    clusters = Analysis.cluster_entries(fis, spine, %{k: 2, m: 2.0})
    assert length(clusters) == 2
    assert Enum.all?(clusters, &Map.has_key?(&1, :centroid))
  end
end
