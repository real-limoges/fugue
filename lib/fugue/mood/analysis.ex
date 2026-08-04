defmodule Fugue.Mood.Analysis do
  @moduledoc """
  Fuzzify -> cluster -> weighted summary, ported from Ish's
  `Ish.Analysis.Fuzzy`.

  Ish's version calls `fuzzifyEntriesWith` (evaluating the FIS on every
  row to append `wellbeing`/`activation` columns) before clustering, but
  `clusterMoodData`'s `extractPresentRows` only ever reads the 5 raw
  dimension columns -- the fuzzified columns are never read downstream.
  That step is skipped here; it has no effect on the result.
  """

  alias Fugue.Mood.Cluster

  @doc "Fuzzify -> cluster -> weighted-summary. Returns `%{clusters:, summary:}`."
  def analyze(fis, spine, config \\ Cluster.default_config()) do
    result = Cluster.run(fis, config, spine)
    %{clusters: result.clusters, summary: summarize(result.clusters)}
  end

  @doc "Fuzzify -> cluster, without the summary. Returns the cluster list."
  def cluster_entries(fis, spine, config \\ Cluster.default_config()) do
    Cluster.run(fis, config, spine).clusters
  end

  defp summarize(clusters) do
    total = Enum.reduce(clusters, 0, &(&1.size + &2))

    clusters
    |> Enum.flat_map(&weight_labels(&1, total))
    |> merge_labels()
  end

  defp weight_labels(cluster, total) do
    w = cluster.size / total
    Enum.map(cluster.labels, fn l -> %{name: l.name, membership: l.membership * w} end)
  end

  # Duplicate label names across clusters merge by taking the max weighted
  # membership, not sum/avg -- ported exactly as Ish's `Map.fromListWith max`.
  defp merge_labels(labels) do
    labels
    |> Enum.reduce(%{}, fn l, acc ->
      Map.update(acc, l.name, l.membership, &max(&1, l.membership))
    end)
    |> Enum.map(fn {name, membership} -> %{name: name, membership: membership} end)
  end
end
