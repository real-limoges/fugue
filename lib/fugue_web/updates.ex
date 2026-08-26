defmodule FugueWeb.Updates do
  @moduledoc """
  Hand-maintained list of site updates, newest first. Backs the `/feed.xml`
  RSS feed. Add an entry here when something ships.
  """

  @entries [
    %{
      title: "Light mode",
      description: "A light theme joins dark, toggleable from the header.",
      url: "/",
      date: ~D[2026-08-22]
    },
    %{
      title: "Hazy and Ish folded into Fugue",
      description:
        "The fuzzy-logic and mood-analysis services are now in-process Elixir " <>
          "(Fugue.Fuzzy, Fugue.Mood) instead of separate deployments.",
      url: "/mood",
      date: ~D[2026-08-03]
    },
    %{
      title: "About and Code pages",
      description: "A small about-me page and a repo index (source links on every route).",
      url: "/about",
      date: ~D[2026-05-09]
    },
    %{
      title: "Color chapter",
      description: "Philosophy-of-mind as color science, told through a protanopia thread.",
      url: "/color",
      date: ~D[2026-05-06]
    }
  ]

  @doc "All update entries, newest first."
  def entries, do: @entries
end
