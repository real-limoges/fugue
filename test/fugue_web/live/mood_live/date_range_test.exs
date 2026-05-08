defmodule FugueWeb.MoodLive.DateRangeTest do
  use ExUnit.Case, async: true

  alias FugueWeb.MoodLive.DateRange

  doctest DateRange

  describe "from_iso_strings/1" do
    test "single-element list returns a degenerate range" do
      assert DateRange.from_iso_strings(["2024-01-01"]) ==
               {~D[2024-01-01], ~D[2024-01-01]}
    end

    test "unsorted input still returns sorted min/max" do
      dates = ["2025-06-01", "2022-01-15", "2026-12-31", "2023-08-08"]
      assert DateRange.from_iso_strings(dates) == {~D[2022-01-15], ~D[2026-12-31]}
    end

    test "malformed entries fall back to the first element" do
      assert DateRange.from_iso_strings(["2024-05-01", "garbage"]) ==
               {~D[2024-05-01], ~D[2024-05-01]}
    end
  end

  describe "format/1" do
    test "nil renders as empty string so callers can interpolate unconditionally" do
      assert DateRange.format(nil) == ""
    end

    test "tuple renders with en-dash separator" do
      assert DateRange.format({"2022-04-01", "2026-03-30"}) ==
               "2022-04-01 – 2026-03-30"
    end
  end
end
