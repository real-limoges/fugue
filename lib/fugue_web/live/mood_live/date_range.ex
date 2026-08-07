defmodule FugueWeb.MoodLive.DateRange do
  @moduledoc """
  Date-range helpers for /mood components. The mood data flows in as ISO-8601
  strings; surfaces consume either parsed `{Date.t(), Date.t()}` tuples (for
  axis math) or formatted strings (for prose). Both shapes lived inline as
  ad-hoc helpers across stream_graph, dimension_drift, and sections, kept
  consistent here so the rendered span never disagrees with the axis bounds.
  """

  @doc """
  Parse a non-empty list of ISO-8601 date strings into `{min, max}` `Date`
  structs. On a malformed entry, falls back to a degenerate range made from
  the first element.

      iex> FugueWeb.MoodLive.DateRange.from_iso_strings(["2026-04-30", "2022-04-01", "2024-08-15"])
      {~D[2022-04-01], ~D[2026-04-30]}
  """
  def from_iso_strings([first | _] = dates) do
    parsed = Enum.map(dates, &Date.from_iso8601!/1)
    {Enum.min(parsed, Date), Enum.max(parsed, Date)}
  rescue
    _ -> {Date.from_iso8601!(first), Date.from_iso8601!(first)}
  end

  @doc """
  Format a `{from, to}` tuple of ISO strings (as produced by `Fugue.Mood.Wire`)
  for inline display. Returns an empty string when the range is missing so
  callers can interpolate it unconditionally.

      iex> FugueWeb.MoodLive.DateRange.format({"2022-04-01", "2026-03-30"})
      "2022-04-01 to 2026-03-30"

      iex> FugueWeb.MoodLive.DateRange.format(nil)
      ""
  """
  def format(nil), do: ""
  def format({from, to}), do: "#{from} to #{to}"
end
