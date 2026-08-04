defmodule Fugue.MoodFixtures do
  @moduledoc """
  Fixture mood data for `Fugue.Mood.*` tests. Carries forward the same
  values the old Ish-HTTP-stub fixtures used (dates translated to
  `Date.t()`, wire-format string keys translated to `Fugue.Mood.Entry`'s
  atom keys) rather than inventing new test data. 19 days, two visually
  distinct mood clusters, and a 3-day gap between 2026-01-14 and
  2026-01-18.
  """

  alias Fugue.Mood.Entry

  @doc "19 fixture entries carried forward from the old Ish-stub fixtures, as `Fugue.Mood.Entry` maps."
  def entries do
    [
      Entry.new("2026-01-01", 6.0, 2.0, 3.0, 8.0, 7.0),
      Entry.new("2026-01-02", 6.5, 2.5, 3.5, 7.5, 7.5),
      Entry.new("2026-01-03", 5.5, 3.0, 4.0, 8.0, 6.5),
      Entry.new("2026-01-04", 6.0, 2.5, 3.5, 7.8, 7.0),
      Entry.new("2026-01-05", 6.2, 2.8, 3.8, 7.6, 6.8),
      Entry.new("2026-01-06", 6.1, 2.6, 3.6, 7.9, 7.1),
      Entry.new("2026-01-07", 6.3, 2.7, 3.7, 7.7, 6.9),
      Entry.new("2026-01-08", 3.0, 7.0, 8.0, 3.0, 2.0),
      Entry.new("2026-01-09", 3.5, 6.5, 7.5, 3.5, 2.5),
      Entry.new("2026-01-10", 2.5, 7.5, 8.5, 2.5, 1.5),
      Entry.new("2026-01-11", 3.0, 7.0, 8.0, 3.0, 2.0),
      Entry.new("2026-01-12", 3.2, 6.8, 7.8, 3.2, 2.2),
      Entry.new("2026-01-13", 3.1, 6.9, 7.9, 3.1, 2.1),
      Entry.new("2026-01-14", 3.3, 6.7, 7.7, 3.3, 2.3),
      Entry.new("2026-01-18", 5.0, 4.0, 5.0, 5.0, 5.0),
      Entry.new("2026-01-19", 5.1, 4.1, 5.1, 5.1, 5.1),
      Entry.new("2026-01-20", 5.2, 4.2, 5.2, 5.2, 5.2),
      Entry.new("2026-01-21", 5.1, 4.1, 5.1, 5.1, 5.1),
      Entry.new("2026-01-22", 5.0, 4.0, 5.0, 5.0, 5.0)
    ]
  end
end
