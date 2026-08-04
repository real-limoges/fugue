defmodule Fugue.Mood.Data do
  @moduledoc """
  Compile-time bundled mood dataset, following
  `Fugue.Menagerie.MelbourneWeather`'s exact pattern. The CSV at
  `priv/static/mood/mood_entries.csv` is a point-in-time export from the
  production Ish SQLite database (`mood_entries` table), pulled via the
  local docker-compose `ish` container's data volume on 2026-08-03,
  spanning 2022-04-01..2026-03-30 (1054 rows). `@external_resource` makes
  this module recompile when the CSV changes. This dataset is a snapshot,
  not a live-synced pipeline -- see the root `CLAUDE.md` framing for why.

  Collapses Ish's identical `/data` and `/entries` endpoints into one
  `between/2` function; there was never a behavioral difference between them.
  """

  alias Fugue.Mood.Entry

  @csv_path "priv/static/mood/mood_entries.csv"
  @external_resource @csv_path

  @entries @csv_path
           |> File.read!()
           |> String.split("\n", trim: true)
           |> tl()
           |> Enum.map(fn line ->
             [date, sleep, anxiety, sensitivity, outlook, speed] = String.split(line, ",")

             Entry.new(
               date,
               String.to_float(sleep),
               String.to_float(anxiety),
               String.to_float(sensitivity),
               String.to_float(outlook),
               String.to_float(speed)
             )
           end)
           |> Enum.sort_by(& &1.date, Date)

  @doc "All bundled entries, date-ascending."
  def all, do: @entries

  @doc """
  Entries with an inclusive date bound on either side. Pass `nil` on either
  side to leave that bound open, matching Ish's optional `from`/`to` query
  params.
  """
  def between(from, to) do
    Enum.filter(@entries, fn entry ->
      (is_nil(from) or Date.compare(entry.date, from) != :lt) and
        (is_nil(to) or Date.compare(entry.date, to) != :gt)
    end)
  end

  @doc "First and last dates in the bundled dataset, or nil if empty."
  def date_range do
    case @entries do
      [] -> nil
      [first | _] = entries -> {first.date, List.last(entries).date}
    end
  end

  @doc "Row count."
  def count, do: length(@entries)
end
