defmodule Fugue.Mood.DataTest do
  use ExUnit.Case, async: true

  alias Fugue.Mood.Data

  test "all/0 returns the bundled dataset, date-ascending, matching the exported row count" do
    entries = Data.all()
    assert length(entries) == 1054
    assert entries == Enum.sort_by(entries, & &1.date, Date)
  end

  test "date_range/0 matches the pinned range MoodLive queries" do
    assert Data.date_range() == {~D[2022-04-01], ~D[2026-03-30]}
  end

  test "count/0 matches all/0's length" do
    assert Data.count() == length(Data.all())
  end

  test "between/2 with both bounds is inclusive" do
    entries = Data.between(~D[2022-04-01], ~D[2022-04-03])
    assert Enum.map(entries, & &1.date) == [~D[2022-04-01], ~D[2022-04-02], ~D[2022-04-03]]
  end

  test "between/2 with a nil bound leaves that side open" do
    from_only = Data.between(~D[2026-03-28], nil)
    assert Enum.map(from_only, & &1.date) |> Enum.all?(&(Date.compare(&1, ~D[2026-03-28]) != :lt))

    to_only = Data.between(nil, ~D[2022-04-02])
    assert Enum.map(to_only, & &1.date) == [~D[2022-04-01], ~D[2022-04-02]]
  end

  test "between/2 with both nil returns everything" do
    assert Data.between(nil, nil) == Data.all()
  end
end
