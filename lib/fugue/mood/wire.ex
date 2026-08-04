defmodule Fugue.Mood.Wire do
  @moduledoc """
  Wire-format adapter matching the JSON shapes Ish's HTTP API used to
  return (`GET /data`, `POST /cluster`, `GET /gaps`), so
  `FugueWeb.MoodLive`'s `DataTransforms`/`GapData`/`Snapshot` layer, which
  parses string-keyed maps in that shape, doesn't need to change.

  `gaps/2` reclusters internally with its own hardcoded `k=3, m=2.0`
  (`Fugue.Mood.Cluster.default_config/0`), independent of whatever `k`/`m`
  a separate `cluster/4` call used -- it does NOT reuse a cluster result
  computed with a caller-supplied `m`. Ish's own `/gaps` handler had this
  same split; a gap transition's before/after cluster membership is not
  comparable to a `/cluster` response computed with different fuzziness.
  """

  alias Fugue.Mood.{Cluster, Data, DataFrame, Fuzzify, Gaps}

  # Not a module attribute: FuzzySet membership functions are closures,
  # which can't be embedded as compile-time attribute literals.
  defp fis, do: Fuzzify.build_mood_fis(Fuzzify.default_membership_func_defs())

  @doc "Matches `Ish.data/2` / `Ish.entries/2` (the two were always identical)."
  def data(from, to) do
    {:ok, Enum.map(Data.between(from, to), &encode_entry/1)}
  end

  @doc "Matches `Ish.cluster/4`'s response shape."
  def cluster(k, m, from, to) do
    result = Cluster.run(fis(), %{k: k, m: m}, spine(from, to))

    {:ok,
     %{
       "clusters" => Enum.map(result.clusters, &encode_cluster/1),
       "centers" => result.centers,
       "membership" => result.membership,
       "iterations" => result.iterations
     }}
  end

  @doc "Matches `Ish.gaps/2`'s response shape, including its independent internal clustering."
  def gaps(from, to) do
    spine = spine(from, to)
    cluster_result = Cluster.run(fis(), Cluster.default_config(), spine)
    result = Gaps.analyze(spine, cluster_result)

    {:ok,
     %{
       "transitions" => Enum.map(result.transitions, &encode_transition/1),
       "lengthDistribution" =>
         Map.new(result.length_distribution, fn {len, n} -> {to_string(len), n} end),
       "imputedMemberships" =>
         Map.new(result.imputed_memberships, fn {date, mems} -> {Date.to_iso8601(date), mems} end)
     }}
  end

  @doc "Matches `Ish.membership_functions/0`'s response shape."
  def membership_functions do
    {:ok, encode_membership_func_defs(Fuzzify.default_membership_func_defs())}
  end

  defp spine(from, to), do: DataFrame.fill_missing_dates(Data.between(from, to))

  defp encode_entry(entry) do
    %{
      "date" => Date.to_iso8601(entry.date),
      "dimensions" => %{
        "sleep" => entry.sleep,
        "anxiety" => entry.anxiety,
        "sensitivity" => entry.sensitivity,
        "outlook" => entry.outlook,
        "speed" => entry.speed
      }
    }
  end

  defp encode_cluster(cluster) do
    %{
      "name" => cluster.name,
      "centroid" => Map.new(cluster.centroid, fn {dim, v} -> {Atom.to_string(dim), v} end),
      "size" => cluster.size,
      "labels" => Enum.map(cluster.labels, &%{"label" => &1.name, "membership" => &1.membership})
    }
  end

  defp encode_transition(t) do
    %{
      "gap" => %{
        "start" => Date.to_iso8601(t.gap.start),
        "length" => t.gap.length,
        "before" => Date.to_iso8601(t.gap.before),
        "after" => Date.to_iso8601(t.gap.after)
      },
      "before" => t.before,
      "after" => t.after,
      "clusterChanged" => t.cluster_changed
    }
  end

  defp encode_membership_func_defs(defs) do
    %{
      "inputs" => Enum.map(defs.inputs, &encode_var_def/1),
      "outputs" => Enum.map(defs.outputs, &encode_var_def/1)
    }
  end

  defp encode_var_def(v) do
    {lo, hi} = v.bounds

    %{
      "name" => v.name,
      "bounds" => [lo, hi],
      "terms" =>
        Enum.map(v.terms, fn t ->
          {a, b, c} = t.params
          %{"name" => t.name, "params" => [a, b, c]}
        end)
    }
  end
end
