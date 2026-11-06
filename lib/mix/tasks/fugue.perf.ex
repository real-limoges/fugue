defmodule Mix.Tasks.Fugue.Perf do
  @shortdoc "Time the /mood connect pipeline and report the size of what it builds"

  @moduledoc """
  Runs the steps of `FugueWeb.MoodLive.Dataset.compute/0` (what /mood used to
  run on every connect) one at a time, and prints how long each took and how
  big its result is, then what `Dataset.load/0` costs cold and warm.

      mix fugue.perf            # 5 runs, median per step
      mix fugue.perf --runs 20

  Sizes are `:erts_debug.flat_size/1` words times the word size, so they are
  the bytes a term occupies once copied onto a process heap (which is what
  `assign/3` and `Task.await/2` do), not its encoded size on the wire.

  This is a measuring tool for the performance work in `docs/roadmap.md`;
  it changes nothing.
  """

  use Mix.Task

  alias Fugue.Mood.Wire
  alias FugueWeb.MoodLive.{Dataset, DataTransforms, Snapshot}
  alias FugueWeb.MoodLive.Structs.GapData

  @impl Mix.Task
  def run(args) do
    {opts, _rest} = OptionParser.parse!(args, strict: [runs: :integer])
    runs = Keyword.get(opts, :runs, 5)

    Mix.Task.run("app.config")

    samples = Enum.map(1..runs, fn _ -> run_pipeline() end)
    last = List.last(samples)

    Mix.shell().info("/mood connect pipeline, #{runs} runs, median ms\n")

    for {step, _ms, _result} <- last do
      times = Enum.map(samples, fn sample -> sample |> List.keyfind!(step, 0) |> elem(1) end)
      {^step, _ms, result} = List.keyfind!(last, step, 0)

      Mix.shell().info(
        String.pad_trailing(Atom.to_string(step), 16) <>
          String.pad_leading(format_ms(median(times)), 10) <>
          String.pad_leading(format_bytes(term_bytes(result)), 12)
      )
    end

    total = Enum.map(samples, fn sample -> sample |> Enum.map(&elem(&1, 1)) |> Enum.sum() end)

    Mix.shell().info(
      "\n" <> String.pad_trailing("total", 16) <> String.pad_leading(format_ms(median(total)), 10)
    )

    # What a connect actually pays: the first Dataset.load/0 computes, every
    # later one reads the shared copy.
    {first_ms, _} = timed(&Dataset.load/0)
    {warm_ms, _} = timed(&Dataset.load/0)

    Mix.shell().info(
      "\nDataset.load/0, first call (Tasks in parallel)" <>
        String.pad_leading(format_ms(first_ms), 10) <>
        "\nDataset.load/0, every later call            " <>
        String.pad_leading(:erlang.float_to_binary(warm_ms, decimals: 3), 10)
    )
  end

  # The steps of Dataset.compute/0, one at a time. Each returns
  # {name, milliseconds, result}. Run sequentially, unlike compute/0's three
  # Tasks, so each step's time is its own.
  defp run_pipeline do
    %{k: k, m: m, from: from, to: to} = Dataset.params()
    {data_ms, {:ok, entries}} = timed(fn -> Wire.data(from, to) end)
    {cluster_ms, {:ok, raw_analysis}} = timed(fn -> Wire.cluster(k, m, from, to) end)
    {gaps_ms, {:ok, raw_gaps}} = timed(fn -> Wire.gaps(from, to) end)
    {parse_ms, analysis} = timed(fn -> DataTransforms.parse_analysis(raw_analysis, entries) end)

    {remap_ms, gaps} =
      timed(fn ->
        raw_gaps |> GapData.from_api() |> DataTransforms.remap_gap_keys(analysis.name_to_id)
      end)

    {snapshot_ms, snapshot} = timed(fn -> Snapshot.from(entries, analysis, gaps) end)

    [
      {:data, data_ms, entries},
      {:cluster, cluster_ms, raw_analysis},
      {:gaps, gaps_ms, raw_gaps},
      {:parse_analysis, parse_ms, analysis},
      {:remap_gaps, remap_ms, gaps},
      {:snapshot, snapshot_ms, snapshot}
    ]
  end

  defp timed(fun) do
    {microseconds, result} = :timer.tc(fun)
    {microseconds / 1000, result}
  end

  defp median(values) do
    sorted = Enum.sort(values)
    Enum.at(sorted, div(length(sorted), 2))
  end

  defp term_bytes(term), do: :erts_debug.flat_size(term) * :erlang.system_info(:wordsize)

  defp format_ms(ms), do: :erlang.float_to_binary(ms / 1, decimals: 1)

  defp format_bytes(bytes) when bytes >= 1_048_576,
    do: :erlang.float_to_binary(bytes / 1_048_576, decimals: 2) <> " MB"

  defp format_bytes(bytes), do: :erlang.float_to_binary(bytes / 1024, decimals: 1) <> " KB"
end
