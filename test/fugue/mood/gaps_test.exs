defmodule Fugue.Mood.GapsTest do
  use ExUnit.Case, async: true

  alias Fugue.Mood.{Cluster, DataFrame, Fuzzify, Gaps}
  alias Fugue.MoodFixtures

  setup do
    fis = Fuzzify.build_mood_fis(Fuzzify.default_membership_func_defs())
    spine = DataFrame.fill_missing_dates(MoodFixtures.entries())
    cluster_result = Cluster.run(fis, %{k: 2, m: 2.0}, spine)
    %{spine: spine, cluster_result: cluster_result}
  end

  test "analyze/2 finds the one fixture gap, with a length histogram and imputed memberships", %{
    spine: spine,
    cluster_result: cluster_result
  } do
    result = Gaps.analyze(spine, cluster_result)

    assert [transition] = result.transitions

    assert transition.gap == %{
             start: ~D[2026-01-15],
             length: 3,
             before: ~D[2026-01-14],
             after: ~D[2026-01-18]
           }

    assert is_boolean(transition.cluster_changed)
    assert map_size(transition.before) == 2
    assert map_size(transition.after) == 2

    assert result.length_distribution == %{3 => 1}

    imputed = result.imputed_memberships

    assert Map.keys(imputed) |> Enum.sort(Date) == [
             ~D[2026-01-15],
             ~D[2026-01-16],
             ~D[2026-01-17]
           ]

    # Interpolation is day-fraction weighted between before/after; every
    # imputed day's membership vector should still sum close to 1.0 since
    # both endpoints are proper (sum-to-1) FCM membership rows.
    for {_day, membership} <- imputed do
      total = membership |> Map.values() |> Enum.sum()
      assert_in_delta total, 1.0, 1.0e-9
    end
  end

  test "the midpoint gap day interpolates halfway between before and after", %{
    spine: spine,
    cluster_result: cluster_result
  } do
    result = Gaps.analyze(spine, cluster_result)
    before = Enum.find(result.transitions, & &1).before
    after_ = Enum.find(result.transitions, & &1).after
    midpoint = result.imputed_memberships[~D[2026-01-16]]

    for {name, before_v} <- before do
      after_v = after_[name]
      assert_in_delta midpoint[name], (before_v + after_v) / 2, 1.0e-9
    end
  end
end
