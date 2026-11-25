defmodule Fugue.Mood.Gaps do
  @moduledoc """
  Gap-transition and imputed-membership analysis, ported from Ish's
  `Ish.Analysis.Gaps`. Requires a `Fugue.Mood.Cluster.run/3` result
  computed against the *same* `spine`.

  Every day that brackets a gap is a complete row (`DataFrame.identify_gaps/1`
  builds gaps between complete runs), and `Cluster.run/3` clusters exactly
  the complete rows, so every bracketing day has a membership. The lookup
  is `Map.fetch!`: a miss means the two were run on different spines.
  """

  alias Fugue.Mood.{Cluster, DataFrame}

  @typedoc "Membership degree by cluster name."
  @type memberships :: %{String.t() => float()}

  @typedoc "A gap with the memberships of the days that bracket it."
  @type transition :: %{
          gap: DataFrame.gap(),
          before: memberships(),
          after: memberships(),
          cluster_changed: boolean()
        }

  @type result :: %{
          transitions: [transition()],
          length_distribution: %{pos_integer() => pos_integer()},
          imputed_memberships: %{Date.t() => memberships()}
        }

  @doc """
  `%{transitions:, length_distribution:, imputed_memberships:}`: per-gap
  before/after cluster-membership vectors and dominant-cluster-changed
  flags, a histogram of gap lengths, and a linear day-fraction
  interpolation of per-cluster membership for every day inside each gap.
  """
  @spec analyze(DataFrame.spine(), Cluster.result()) :: result()
  def analyze(spine, cluster_result) do
    gaps = DataFrame.identify_gaps(spine)
    by_date = memberships_by_date(cluster_result)

    %{
      transitions: Enum.map(gaps, &compute_transition(&1, by_date)),
      length_distribution: Enum.frequencies_by(gaps, & &1.length),
      imputed_memberships: gaps |> Enum.flat_map(&impute_gap(&1, by_date)) |> Map.new()
    }
  end

  defp memberships_by_date(cluster_result) do
    names = Enum.map(cluster_result.clusters, & &1.name)

    cluster_result.dates
    |> Enum.zip(cluster_result.membership)
    |> Map.new(fn {date, row} -> {date, names |> Enum.zip(row) |> Map.new()} end)
  end

  defp dominant_cluster(membership) do
    {name, _degree} = Enum.max_by(membership, fn {_name, degree} -> degree end)
    name
  end

  defp compute_transition(gap, by_date) do
    before = Map.fetch!(by_date, gap.before)
    after_ = Map.fetch!(by_date, gap.after)

    %{
      gap: gap,
      before: before,
      after: after_,
      cluster_changed: dominant_cluster(before) != dominant_cluster(after_)
    }
  end

  defp impute_gap(gap, by_date) do
    before = Map.fetch!(by_date, gap.before)
    after_ = Map.fetch!(by_date, gap.after)
    total_days = Date.diff(gap.after, gap.before)

    for day <- Date.range(Date.add(gap.before, 1), Date.add(gap.after, -1)) do
      w = Date.diff(day, gap.before) / total_days
      {day, interpolate(before, after_, w)}
    end
  end

  # Both sides carry every cluster name, since both come from one
  # clustering.
  defp interpolate(before, after_, w) do
    Map.new(before, fn {name, b} -> {name, (1 - w) * b + w * Map.fetch!(after_, name)} end)
  end
end
