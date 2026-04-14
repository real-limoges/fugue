defmodule Fugue.IshFixtures do
  @moduledoc """
  Deterministic JSON payloads matching the real Ish API shapes so tests can
  stub HTTP responses without pinning themselves to random Ish server output.
  Shapes mirror `Ish.Types`, `Ish.Analysis.Cluster.ClusterResult`, and
  `Ish.Analysis.Gaps.GapAnalysis` in the upstream Haskell service.
  """

  @dimensions ~w(sleep anxiety sensitivity outlook speed)

  @doc "A small but realistic slice of mood entries spanning ~20 days."
  def entries do
    [
      entry("2026-01-01", 6.0, 2.0, 3.0, 8.0, 7.0),
      entry("2026-01-02", 6.5, 2.5, 3.5, 7.5, 7.5),
      entry("2026-01-03", 5.5, 3.0, 4.0, 8.0, 6.5),
      entry("2026-01-04", 6.0, 2.5, 3.5, 7.8, 7.0),
      entry("2026-01-05", 6.2, 2.8, 3.8, 7.6, 6.8),
      entry("2026-01-06", 6.1, 2.6, 3.6, 7.9, 7.1),
      entry("2026-01-07", 6.3, 2.7, 3.7, 7.7, 6.9),
      entry("2026-01-08", 3.0, 7.0, 8.0, 3.0, 2.0),
      entry("2026-01-09", 3.5, 6.5, 7.5, 3.5, 2.5),
      entry("2026-01-10", 2.5, 7.5, 8.5, 2.5, 1.5),
      entry("2026-01-11", 3.0, 7.0, 8.0, 3.0, 2.0),
      entry("2026-01-12", 3.2, 6.8, 7.8, 3.2, 2.2),
      entry("2026-01-13", 3.1, 6.9, 7.9, 3.1, 2.1),
      entry("2026-01-14", 3.3, 6.7, 7.7, 3.3, 2.3),
      entry("2026-01-18", 5.0, 4.0, 5.0, 5.0, 5.0),
      entry("2026-01-19", 5.1, 4.1, 5.1, 5.1, 5.1),
      entry("2026-01-20", 5.2, 4.2, 5.2, 5.2, 5.2),
      entry("2026-01-21", 5.1, 4.1, 5.1, 5.1, 5.1),
      entry("2026-01-22", 5.0, 4.0, 5.0, 5.0, 5.0)
    ]
  end

  defp entry(date, sleep, anxiety, sensitivity, outlook, speed) do
    %{
      "date" => date,
      "dimensions" => %{
        "sleep" => sleep,
        "anxiety" => anxiety,
        "sensitivity" => sensitivity,
        "outlook" => outlook,
        "speed" => speed
      }
    }
  end

  @doc """
  A cluster API response with `k` clusters whose membership rows match
  `entries/0` one-to-one. Clusters are strongly separated so dominant-
  cluster assignment is deterministic regardless of fuzziness.
  """
  def cluster_response(k \\ 3) do
    clusters =
      for i <- 0..(k - 1) do
        %{
          "name" => "raw_#{i}",
          "centroid" => Map.new(@dimensions, fn d -> {d, 5.0 + i} end),
          "size" => 6,
          "labels" => []
        }
      end

    membership =
      entries()
      |> Enum.with_index()
      |> Enum.map(fn {entry, idx} -> membership_row(entry, idx, k) end)

    %{
      "clusters" => clusters,
      "centers" => for(i <- 0..(k - 1), do: for(_ <- 0..4, do: 5.0 + i)),
      "membership" => membership,
      "iterations" => 12
    }
  end

  # Produces a one-hot-ish membership row so the dominant cluster is obvious.
  # First 7 entries belong to cluster 0, next 7 to cluster 1, rest to cluster 2.
  defp membership_row(_entry, idx, k) do
    target =
      cond do
        idx < 7 -> 0
        idx < 14 -> 1
        true -> 2
      end

    target = min(target, k - 1)

    for c <- 0..(k - 1) do
      if c == target, do: 0.9, else: 0.1 / max(k - 1, 1)
    end
  end

  @doc "A gaps payload matching `entries/0` — one 3-day gap between Jan 14 and Jan 18."
  def gaps_response do
    %{
      "transitions" => [
        %{
          "before" => %{"raw_1" => 0.9, "raw_0" => 0.05, "raw_2" => 0.05},
          "after" => %{"raw_2" => 0.9, "raw_0" => 0.05, "raw_1" => 0.05}
        }
      ],
      "lengthDistribution" => %{"3" => 1},
      "imputedMemberships" => %{
        "2026-01-15" => %{"raw_1" => 0.7, "raw_2" => 0.3},
        "2026-01-16" => %{"raw_1" => 0.5, "raw_2" => 0.5},
        "2026-01-17" => %{"raw_1" => 0.3, "raw_2" => 0.7}
      }
    }
  end

  @doc "A minimal but valid `MembershipFuncDefs` with the 5 input dims."
  def membership_defs do
    %{
      "inputs" => Enum.map(@dimensions, &input_var/1),
      "outputs" => []
    }
  end

  @doc "A suggested `MembershipFuncDefs` — same shape, different peaks."
  def suggested_membership_defs do
    suggested =
      Enum.map(@dimensions, fn dim ->
        %{
          "name" => dim,
          "bounds" => [0.0, 10.0],
          "terms" => [
            %{"name" => "low", "params" => [0.0, 1.5, 4.0]},
            %{"name" => "medium", "params" => [2.0, 5.0, 8.0]},
            %{"name" => "high", "params" => [6.0, 8.5, 10.0]}
          ]
        }
      end)

    %{"inputs" => suggested, "outputs" => []}
  end

  defp input_var(dim) do
    %{
      "name" => dim,
      "bounds" => [0.0, 10.0],
      "terms" => [
        %{"name" => "low", "params" => [0.0, 2.0, 5.0]},
        %{"name" => "medium", "params" => [3.0, 5.0, 7.0]},
        %{"name" => "high", "params" => [5.0, 8.0, 10.0]}
      ]
    }
  end
end
