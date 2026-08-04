defmodule Fugue.Mood.EntryTest do
  use ExUnit.Case, async: true

  alias Fugue.Mood.Entry

  test "new/6 parses the date and carries the 5 dimensions" do
    entry = Entry.new("2026-01-01", 6.0, 2.0, 3.0, 8.0, 7.0)

    assert entry.date == ~D[2026-01-01]
    assert entry.sleep == 6.0
    assert entry.anxiety == 2.0
    assert entry.sensitivity == 3.0
    assert entry.outlook == 8.0
    assert entry.speed == 7.0
  end

  test "complete?/1 is true only when all 5 dimensions are present" do
    full = Entry.new("2026-01-01", 6.0, 2.0, 3.0, 8.0, 7.0)
    partial = %{full | sleep: nil}

    assert Entry.complete?(full)
    refute Entry.complete?(partial)
  end

  test "point/1 returns the fixed dimension order" do
    entry = Entry.new("2026-01-01", 6.0, 2.0, 3.0, 8.0, 7.0)
    assert Entry.point(entry) == [6.0, 2.0, 3.0, 8.0, 7.0]
  end
end
