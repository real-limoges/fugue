defmodule FugueWeb.FeedController do
  @moduledoc false
  use FugueWeb, :controller

  def rss(conn, _params) do
    xml = render_rss(FugueWeb.Updates.entries(), FugueWeb.Endpoint.url())

    conn
    |> put_resp_content_type("application/rss+xml")
    |> send_resp(200, xml)
  end

  defp render_rss(entries, base_url) do
    items = Enum.map_join(entries, "\n", &render_item(&1, base_url))

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <title>realcomplex.systems</title>
        <link>#{base_url}</link>
        <description>Updates from realcomplex.systems.</description>
        <language>en-us</language>
    #{items}
      </channel>
    </rss>
    """
  end

  defp render_item(entry, base_url) do
    link = base_url <> entry.url
    pub_date = rfc822(entry.date)

    """
      <item>
        <title>#{escape(entry.title)}</title>
        <link>#{link}</link>
        <guid isPermaLink="false">#{link}##{entry.date}</guid>
        <description>#{escape(entry.description)}</description>
        <pubDate>#{pub_date}</pubDate>
      </item>
    """
  end

  defp rfc822(date) do
    date
    |> DateTime.new!(~T[00:00:00], "Etc/UTC")
    |> Calendar.strftime("%a, %d %b %Y %H:%M:%S %z")
  end

  defp escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end
end
