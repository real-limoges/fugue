defmodule FugueWeb.ProseTest do
  @moduledoc """
  Guards the site's punctuation conventions at the file level.

  The house style is ASCII: no em-dashes, no en-dashes, no ellipsis
  character, no curly quotes. This is easy to reintroduce by accident, and
  it never fails loudly on its own, so it gets a test rather than a note.

  Deliberately file-level rather than route-level: a rendered-page check
  would only cover prose that happens to be on screen for the default
  assigns, and would miss copy behind a toggle, a JS hook string, or a
  section that only appears once you drag something.
  """
  use ExUnit.Case, async: true

  @banned %{
    "em-dash (—)" => "—",
    "en-dash (–)" => "–",
    "ellipsis (…)" => "…",
    "curly apostrophe (’)" => "’",
    "curly open quote (“)" => "“",
    "curly close quote (”)" => "”"
  }

  # Vendored upstream drops are not ours to restyle; see assets/vendor/CLAUDE.md.
  defp source_files do
    Path.wildcard("lib/**/*.{ex,heex}") ++
      Path.wildcard("assets/js/**/*.js") ++
      Path.wildcard("assets/css/*.css")
  end

  test "no smart punctuation in shipped source" do
    offenders =
      for path <- source_files(),
          not String.contains?(path, "vendor"),
          content = File.read!(path),
          {label, char} <- @banned,
          String.contains?(content, char) do
        line =
          content
          |> String.split("\n")
          |> Enum.find_index(&String.contains?(&1, char))
          |> then(&((&1 || 0) + 1))

        "#{path}:#{line} contains #{label}"
      end

    assert offenders == [],
           "Use ASCII punctuation. Offenders:\n" <> Enum.join(offenders, "\n")
  end
end
