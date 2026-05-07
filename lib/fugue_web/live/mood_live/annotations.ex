defmodule FugueWeb.MoodLive.Annotations do
  @moduledoc """
  Personal milestones overlaid on the mood trajectory in the /mood hero.

  Each entry pins a short label to a specific date. The trajectory marks the
  projected point with a small ring, renders the label nearby with a leader
  line, and shows a tooltip on hover with the full note.

  ## Adding an entry

  Append a map to the `@annotations` list below. Order doesn't matter -- the
  renderer sorts by date. Dates not in the dataset are skipped with a
  console warning.

  Fields:

    * `:date` -- required, "YYYY-MM-DD"
    * `:label` -- required, the short text shown next to the marker. Keep it
      to ~30 characters; it has to fit in the hero margin. The headline.
    * `:note` -- optional, the full sentence shown on hover. This is where
      you actually say what happened. Wrapping is fine.

  Example:

      %{
        date: "2022-06-25",
        label: "got married",
        note: "Backyard ceremony, ninety degrees, everybody cried."
      }
  """

  @annotations [
    # %{date: "2022-06-25", label: "got married", note: "what happened that day"},
  ]

  @doc "Returns all trajectory annotations in their authored order."
  def all, do: @annotations
end
