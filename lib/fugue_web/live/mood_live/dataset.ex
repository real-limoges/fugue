defmodule FugueWeb.MoodLive.Dataset do
  @moduledoc """
  Everything /mood shows, computed once per node and kept in
  `:persistent_term`.

  The inputs never change at runtime: the dataset is compiled into
  `Fugue.Mood.Data`, the date range is pinned, and `k`/`m` are constants. So
  the analysis is the same for every visitor, and running it per connect cost
  about 225 ms of CPU and left about 2.7 MB on each socket's heap
  (performance baseline P4, 2026-11-05). A term read from `:persistent_term`
  is not copied onto the reading process's heap, so sockets that assign it
  share one copy.

  Same shape as `Fugue.Color.SrgbGamut.cells/0`: computed on first use.
  `mix fugue.perf` times the individual steps of `compute/0`.
  """

  alias Fugue.Mood.Wire
  alias FugueWeb.MoodLive.{DataTransforms, Snapshot}
  alias FugueWeb.MoodLive.Structs.{AnalysisResult, GapData}

  @k 3
  @m 1.5

  # Pinned so clusters stay stable as new entries land. Bump when promoting an epilogue.
  @from ~D[2022-04-01]
  @to ~D[2026-03-30]

  @key {__MODULE__, :dataset}

  @enforce_keys [:entries, :analysis, :gaps, :snapshot, :dates]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          entries: [DataTransforms.wire_entry()],
          analysis: AnalysisResult.t(),
          gaps: GapData.t(),
          snapshot: Snapshot.t(),
          dates: [DataTransforms.iso_date()]
        }

  @doc "The dataset, computed on the first call and shared after that."
  @spec load() :: t()
  def load do
    case :persistent_term.get(@key, nil) do
      nil ->
        :persistent_term.put(@key, compute())
        # Read it back rather than returning compute/0's result: that one
        # lives on this process's heap, and the caller would keep a private
        # copy instead of sharing the stored one.
        :persistent_term.get(@key)

      dataset ->
        dataset
    end
  end

  @doc """
  Runs the whole analysis. Clustering and gap analysis each run their own
  FCM, independently (see `Fugue.Mood.Wire`), so they run in parallel.
  """
  @spec compute() :: t()
  def compute do
    tasks = %{
      data: Task.async(fn -> Wire.data(@from, @to) end),
      analysis: Task.async(fn -> Wire.cluster(@k, @m, @from, @to) end),
      gaps: Task.async(fn -> Wire.gaps(@from, @to) end)
    }

    results = Map.new(tasks, fn {key, task} -> {key, Task.await(task, 15_000)} end)

    {:ok, entries} = results.data
    {:ok, raw_analysis} = results.analysis
    {:ok, raw_gaps} = results.gaps

    analysis = DataTransforms.parse_analysis(raw_analysis, entries)
    gaps = raw_gaps |> GapData.from_api() |> DataTransforms.remap_gap_keys(analysis.name_to_id)

    %__MODULE__{
      entries: entries,
      analysis: analysis,
      gaps: gaps,
      snapshot: Snapshot.from(entries, analysis, gaps),
      dates: Enum.map(entries, & &1["date"])
    }
  end

  @doc "The constants `compute/0` runs with, for `mix fugue.perf`."
  @spec params() :: %{k: pos_integer(), m: float(), from: Date.t(), to: Date.t()}
  def params, do: %{k: @k, m: @m, from: @from, to: @to}
end
