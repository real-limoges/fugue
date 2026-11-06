defmodule FugueWeb.MoodLive.DatasetTest do
  use ExUnit.Case, async: true

  alias FugueWeb.MoodLive.Dataset

  test "load/0 returns the full analysis and the same shared term every time" do
    first = Dataset.load()

    assert %Dataset{} = first
    assert first.entries != []
    assert length(first.dates) == length(first.entries)
    assert first.snapshot.calendar_days != []

    # Not just equal: the same term, read from :persistent_term, not rebuilt.
    assert :erts_debug.same(first, Dataset.load())
  end

  test "load/0 matches a fresh compute/0" do
    assert Dataset.load() == Dataset.compute()
  end
end
