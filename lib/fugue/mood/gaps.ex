defmodule Fugue.Mood.Gaps do
  @moduledoc """
  Gap-transition and imputed-membership analysis, ported from Ish's
  `Ish.Analysis.Gaps`. Requires a `Fugue.Mood.Cluster.run/3` result
  computed against the *same* `spine` (its `dates`/`membership` must be
  positionally aligned to look up a day's cluster membership).
  """

  alias Fugue.Mood.DataFrame

  @doc """
  `%{transitions:, length_distribution:, imputed_memberships:}` -- per-gap
  before/after cluster-membership vectors and dominant-cluster-changed
  flags, a histogram of gap lengths, and a linear day-fraction
  interpolation of per-cluster membership for every day inside each gap.
  """
  def analyze(spine, cluster_result) do
    gaps = DataFrame.identify_gaps(spine)

    date_to_idx = cluster_result.dates |> Enum.with_index() |> Map.new()
    cluster_names = Enum.map(cluster_result.clusters, & &1.name)
    lookup = fn day -> lookup_membership(cluster_result, date_to_idx, cluster_names, day) end

    %{
      transitions: Enum.map(gaps, &compute_transition(&1, lookup)),
      length_distribution: Enum.frequencies_by(gaps, & &1.length),
      imputed_memberships: gaps |> Enum.flat_map(&impute_gap(&1, lookup)) |> Map.new()
    }
  end

  defp lookup_membership(cluster_result, date_to_idx, cluster_names, day) do
    case Map.get(date_to_idx, day) do
      nil -> %{}
      idx -> cluster_names |> Enum.zip(Enum.at(cluster_result.membership, idx)) |> Map.new()
    end
  end

  defp dominant_cluster(membership) do
    case Enum.max_by(membership, fn {_name, degree} -> degree end, fn -> {"", 0} end) do
      {name, _degree} -> name
    end
  end

  defp compute_transition(gap, lookup) do
    before = lookup.(gap.before)
    after_ = lookup.(gap.after)

    %{
      gap: gap,
      before: before,
      after: after_,
      cluster_changed: dominant_cluster(before) != dominant_cluster(after_)
    }
  end

  defp impute_gap(gap, lookup) do
    before = lookup.(gap.before)
    after_ = lookup.(gap.after)
    total_days = Date.diff(gap.after, gap.before)

    for day <- Date.range(Date.add(gap.before, 1), Date.add(gap.after, -1)) do
      w = Date.diff(day, gap.before) / total_days
      {day, interpolate(before, after_, w)}
    end
  end

  defp interpolate(before, after_, w) do
    (Map.keys(before) ++ Map.keys(after_))
    |> Enum.uniq()
    |> Map.new(fn name ->
      b = Map.get(before, name, 0.0)
      a = Map.get(after_, name, 0.0)
      {name, (1 - w) * b + w * a}
    end)
  end
end
