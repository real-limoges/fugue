defmodule FugueWeb.BlogHTML do
  @moduledoc false
  use FugueWeb, :html

  embed_templates "blog_html/*"

  @tag_styles [
    "text-primary border-primary/40 bg-primary/10 hover:bg-primary/20",
    "text-secondary border-secondary/40 bg-secondary/10 hover:bg-secondary/20",
    "text-accent border-accent/40 bg-accent/10 hover:bg-accent/20",
    "text-info border-info/40 bg-info/10 hover:bg-info/20",
    "text-success border-success/40 bg-success/10 hover:bg-success/20",
    "text-warning border-warning/40 bg-warning/10 hover:bg-warning/20",
    "text-error border-error/40 bg-error/10 hover:bg-error/20"
  ]

  def tag_classes(tag) do
    index = :erlang.phash2(tag, length(@tag_styles))
    Enum.at(@tag_styles, index)
  end

  def feed_xml(posts) do
    updated = if post = List.first(posts), do: "#{post.date}T00:00:00Z", else: ""

    entries =
      for post <- posts do
        escaped_body =
          post.body
          |> Phoenix.HTML.html_escape()
          |> Phoenix.HTML.safe_to_string()

        """
        <entry>
          <title>#{xml_escape(post.title)}</title>
          <link href="https://realcomplex.systems/blog/#{post.slug}"/>
          <id>https://realcomplex.systems/blog/#{post.slug}</id>
          <updated>#{post.date}T00:00:00Z</updated>
          <summary>#{xml_escape(post.summary)}</summary>
          <content type="html">#{escaped_body}</content>
        </entry>
        """
      end

    """
    <?xml version="1.0" encoding="utf-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom">
      <title>realcomplex.systems</title>
      <link href="https://realcomplex.systems/blog/feed.xml" rel="self"/>
      <link href="https://realcomplex.systems"/>
      <id>https://realcomplex.systems/blog</id>
      <updated>#{updated}</updated>
      #{Enum.join(entries)}
    </feed>
    """
  end

  defp xml_escape(str) do
    str
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
