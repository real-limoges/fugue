defmodule Fugue.Mood.Cluster do
  @moduledoc """
  FCM-backed mood clustering, ported from Ish's `Ish.Analysis.Cluster`.

  `default_config/0` is `k=3, m=2.0`, matching Ish's internal default.
  Callers that need a different fuzziness (e.g. `FugueWeb.MoodLive` uses
  `k=3, m=1.5`) must pass it explicitly -- don't fold a caller-supplied
  `m` into this default, since `Fugue.Mood.Wire.gaps/2` depends on this
  default staying independent of whatever `/cluster` was called with.

  Center-label thresholds are derived from the output variable's actual
  bounds (`low + range/3`, `low + 2*range/3`) rather than Ish's hardcoded
  `3.33`/`6.67`, which silently assumed a 0-10 scale. Under the default
  bounds (0-10) this reduces to the same numbers; it only differs if
  output bounds are ever edited via the membership-functions UI.
  """

  alias Fugue.Fuzzy.{FCM, Inference}
  alias Fugue.Mood.DataFrame

  @doc "Default cluster config: `%{k: 3, m: 2.0}`."
  def default_config, do: %{k: 3, m: 2.0}

  @doc """
  Run FCM clustering on the present-data rows of `spine`, labeling each
  resulting center by running it back through `fis`. Returns
  `%{clusters:, centers:, membership:, iterations:, dates:}` -- `dates`
  is the point-order date list, positionally aligned with `membership`'s
  rows, for callers (gap analysis) that need to relate a membership row
  back to a calendar date.
  """
  def run(fis, config, spine) do
    present = DataFrame.extract_present_rows(spine)
    points = Enum.map(present, & &1.point)
    dates = Enum.map(present, & &1.date)

    fcm_config = %{clusters: config.k, fuzziness: config.m, epsilon: 1.0e-5, max_iter: 100}
    result = FCM.run(fcm_config, points)

    %{
      clusters: label_centers(fis, result.centers, result.membership),
      centers: result.centers,
      membership: result.membership,
      iterations: result.iterations,
      dates: dates
    }
  end

  defp label_centers(fis, centers, membership) do
    dims = Fugue.Mood.Entry.dimension_order()
    dim_names = Enum.map(dims, &Atom.to_string/1)

    centers
    |> Enum.with_index()
    |> Enum.map(fn {center, i} ->
      centroid = dims |> Enum.zip(center) |> Map.new()
      fis_input = dim_names |> Enum.zip(center) |> Map.new()
      fis_output = Inference.Mamdani.run(fis, fis_input)

      labels =
        for {out_var, degree} <- fis_output do
          %{name: "#{out_var} #{level(fis, out_var, degree)}", membership: degree}
        end

      %{
        name: Enum.map_join(labels, " / ", & &1.name),
        centroid: centroid,
        size: Enum.count(membership, &(argmax_index(&1) == i)),
        labels: labels
      }
    end)
  end

  defp level(fis, out_var, degree) do
    {lo, hi} = fis.outputs[out_var].bounds
    third = (hi - lo) / 3

    cond do
      degree > lo + 2 * third -> "high"
      degree > lo + third -> "medium"
      true -> "low"
    end
  end

  defp argmax_index(row) do
    row |> Enum.with_index() |> Enum.max_by(fn {v, _idx} -> v end) |> elem(1)
  end
end
