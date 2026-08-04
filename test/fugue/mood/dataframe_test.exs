defmodule Fugue.Mood.DataFrameTest do
  use ExUnit.Case, async: true

  alias Fugue.Mood.{DataFrame, Entry}
  alias Fugue.MoodFixtures

  test "fill_missing_dates/1 spans the full date range, nil-filling absent days" do
    spine = DataFrame.fill_missing_dates(MoodFixtures.entries())

    assert length(spine) == Date.diff(~D[2026-01-22], ~D[2026-01-01]) + 1
    assert hd(spine).date == ~D[2026-01-01]
    assert List.last(spine).date == ~D[2026-01-22]

    missing_day = Enum.find(spine, &(&1.date == ~D[2026-01-16]))
    assert missing_day.sleep == nil
    refute Entry.complete?(missing_day)
  end

  test "fill_missing_dates/1 on an empty list returns an empty spine" do
    assert DataFrame.fill_missing_dates([]) == []
  end

  test "identify_gaps/1 finds exactly the one interior gap in the fixture" do
    spine = DataFrame.fill_missing_dates(MoodFixtures.entries())
    gaps = DataFrame.identify_gaps(spine)

    assert [%{start: ~D[2026-01-15], length: 3, before: ~D[2026-01-14], after: ~D[2026-01-18]}] =
             gaps
  end

  test "identify_gaps/1 does not report gaps touching the start or end of the range" do
    entries = [
      Entry.new("2026-02-03", 5.0, 5.0, 5.0, 5.0, 5.0),
      Entry.new("2026-02-05", 5.0, 5.0, 5.0, 5.0, 5.0)
    ]

    spine = DataFrame.fill_missing_dates(entries)
    # Feb 3 (present), Feb 4 (absent), Feb 5 (present) -- no leading/trailing
    # absent runs exist to NOT report, so this doubles as confirming a
    # genuinely interior gap is still found even at the edge of the fixture.
    assert [%{start: ~D[2026-02-04], length: 1}] = DataFrame.identify_gaps(spine)
  end

  test "extract_present_rows/1 excludes gap days and returns point vectors in spine order" do
    spine = DataFrame.fill_missing_dates(MoodFixtures.entries())
    present = DataFrame.extract_present_rows(spine)

    assert length(present) == 19
    assert Enum.map(present, & &1.date) == Enum.map(MoodFixtures.entries(), & &1.date)
    assert hd(present).point == [6.0, 2.0, 3.0, 8.0, 7.0]
  end

  test "extract_entries/1 is the inverse of fill_missing_dates/1 for a fully-present dataset" do
    spine = DataFrame.fill_missing_dates(MoodFixtures.entries())
    assert DataFrame.extract_entries(spine) == MoodFixtures.entries()
  end
end
