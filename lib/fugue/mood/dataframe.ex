defmodule Fugue.Mood.DataFrame do
  @moduledoc """
  Date-spine and gap-detection helpers, ported from Ish's
  `Ish.Analysis.DataFrame`. Rows are plain maps (`%{date:, sleep:,
  anxiety:, sensitivity:, outlook:, speed:}`, dimensions `nil` when
  missing) rather than a tabular-data-library structure -- Ish's
  `dataframe` dependency was confirmed to do nothing beyond typed
  named-column storage here, so plain `Enum`/`Map` row-of-maps replicate
  it with zero risk.
  """

  alias Fugue.Mood.Entry

  @doc """
  Build the full date-spine from the earliest to the latest entry
  (inclusive), filling in `nil` for any dimension on days with no entry.
  """
  def fill_missing_dates([]), do: []

  def fill_missing_dates(entries) do
    by_date = Map.new(entries, &{&1.date, &1})
    dates = Enum.map(entries, & &1.date)
    min_date = Enum.min(dates, Date)
    max_date = Enum.max(dates, Date)

    for date <- Date.range(min_date, max_date) do
      case Map.get(by_date, date) do
        nil -> %{date: date, sleep: nil, anxiety: nil, sensitivity: nil, outlook: nil, speed: nil}
        entry -> entry
      end
    end
  end

  @doc """
  Interior gaps only: a run of consecutive absent days bracketed by a
  present day on both sides. Gaps touching the very start or end of the
  date range are not reported (there's no bracketing present day to
  compute a transition from/to).
  """
  def identify_gaps(spine) when length(spine) < 2, do: []

  def identify_gaps(spine) do
    runs = Enum.chunk_by(spine, &Entry.complete?/1)
    triplets = Enum.zip([runs, Enum.drop(runs, 1), Enum.drop(runs, 2)])

    triplets
    |> Enum.flat_map(fn {before, gap, after_run} ->
      if Entry.complete?(hd(gap)) do
        []
      else
        [
          %{
            start: hd(gap).date,
            length: length(gap),
            before: List.last(before).date,
            after: hd(after_run).date
          }
        ]
      end
    end)
  end

  @doc "Rows where all 5 dimensions are present, as `%{date:, point: [...]}` in spine order."
  def extract_present_rows(spine) do
    spine
    |> Enum.filter(&Entry.complete?/1)
    |> Enum.map(&%{date: &1.date, point: Entry.point(&1)})
  end

  @doc "Rows where all 5 dimensions are present, as entries (the inverse of `fill_missing_dates/1`)."
  def extract_entries(spine), do: Enum.filter(spine, &Entry.complete?/1)
end
