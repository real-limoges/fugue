defmodule Fugue.Blog do
  @moduledoc """
  Compile-time blog engine. Parses all markdown posts in priv/blog/ at compile
  time using @external_resource so the module recompiles when posts change.
  """

  alias Fugue.Blog.{Post, Parser}

  @blog_dir "priv/blog"

  blog_paths =
    @blog_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".md"))
    |> Enum.map(&Path.join(@blog_dir, &1))

  posts =
    for path <- blog_paths do
      @external_resource path

      slug = path |> Path.basename() |> Path.rootname()
      raw = File.read!(path)

      {frontmatter, body} = Parser.split_frontmatter(raw)

      %Post{
        slug: slug,
        title: frontmatter["title"] || slug,
        date: Parser.parse_date(frontmatter["date"]),
        body: Earmark.as_html!(body),
        tags: Parser.parse_tags(frontmatter["tags"]),
        summary: frontmatter["summary"] || "",
        draft: Parser.parse_draft(frontmatter["draft"])
      }
    end
    |> Enum.sort_by(& &1.date, {:desc, Date})

  @posts posts
  @non_draft_posts Enum.reject(posts, & &1.draft)
  @all_tags posts |> Enum.flat_map(& &1.tags) |> Enum.uniq() |> Enum.sort()
  @non_draft_tags @non_draft_posts |> Enum.flat_map(& &1.tags) |> Enum.uniq() |> Enum.sort()

  def list_posts(opts \\ []) do
    tag = Keyword.get(opts, :tag)

    posts()
    |> then(fn posts ->
      if tag, do: Enum.filter(posts, &(tag in &1.tags)), else: posts
    end)
  end

  def get_post(slug) do
    case Enum.find(posts(), &(&1.slug == slug)) do
      nil -> :error
      post -> {:ok, post}
    end
  end

  def all_tags, do: if(show_drafts?(), do: @all_tags, else: @non_draft_tags)

  defp posts do
    if show_drafts?(), do: @posts, else: @non_draft_posts
  end

  defp show_drafts? do
    Application.get_env(:fugue, :show_draft_posts, false)
  end
end
