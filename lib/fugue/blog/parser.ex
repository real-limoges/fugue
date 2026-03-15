defmodule Fugue.Blog.Parser do
  @moduledoc false

  def split_frontmatter("---\n" <> rest) do
    case String.split(rest, "\n---\n", parts: 2) do
      [fm, body] ->
        attrs =
          fm
          |> String.split("\n")
          |> Enum.map(&String.split(&1, ": ", parts: 2))
          |> Enum.filter(&(length(&1) == 2))
          |> Map.new(fn [k, v] -> {String.trim(k), String.trim(v)} end)

        {attrs, body}

      _ ->
        {%{}, rest}
    end
  end

  def split_frontmatter(content), do: {%{}, content}

  def parse_date(nil), do: nil

  def parse_date(str) do
    case Date.from_iso8601(str) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  def parse_tags(nil), do: []
  def parse_tags(""), do: []

  def parse_tags(str) do
    str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  def parse_draft(nil), do: false
  def parse_draft("true"), do: true
  def parse_draft("false"), do: false
  def parse_draft(_), do: false
end
