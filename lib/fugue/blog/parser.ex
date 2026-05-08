defmodule Fugue.Blog.Parser do
  @moduledoc false

  @doc """
  Splits leading YAML-ish frontmatter from a markdown post body. Returns
  `{attrs_map, body}`; falls back to `{%{}, content}` when no frontmatter
  is present.

      iex> Fugue.Blog.Parser.split_frontmatter("---\\ntitle: Hi\\n---\\nbody")
      {%{"title" => "Hi"}, "body"}

      iex> Fugue.Blog.Parser.split_frontmatter("plain body")
      {%{}, "plain body"}
  """
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

  @doc """
  Parses an ISO-8601 date string. Returns `nil` for missing or malformed
  input rather than raising — frontmatter is best-effort.

      iex> Fugue.Blog.Parser.parse_date("2026-04-30")
      ~D[2026-04-30]

      iex> Fugue.Blog.Parser.parse_date(nil)
      nil

      iex> Fugue.Blog.Parser.parse_date("not-a-date")
      nil
  """
  def parse_date(nil), do: nil

  def parse_date(str) do
    case Date.from_iso8601(str) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  @doc """
  Splits a comma-separated tags string into a trimmed list, dropping
  empty entries.

      iex> Fugue.Blog.Parser.parse_tags("elixir, color , ")
      ["elixir", "color"]

      iex> Fugue.Blog.Parser.parse_tags(nil)
      []
  """
  def parse_tags(nil), do: []
  def parse_tags(""), do: []

  def parse_tags(str) do
    str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  @doc """
  Coerces a frontmatter draft flag. Anything that isn't the literal
  string `"true"` is treated as published.

      iex> Fugue.Blog.Parser.parse_draft("true")
      true

      iex> Fugue.Blog.Parser.parse_draft("false")
      false

      iex> Fugue.Blog.Parser.parse_draft(nil)
      false
  """
  def parse_draft(nil), do: false
  def parse_draft("true"), do: true
  def parse_draft("false"), do: false
  def parse_draft(_), do: false
end
