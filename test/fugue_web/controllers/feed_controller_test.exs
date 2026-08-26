defmodule FugueWeb.FeedControllerTest do
  use FugueWeb.ConnCase

  test "GET /feed.xml returns a well-formed RSS 2.0 document", %{conn: conn} do
    conn = get(conn, ~p"/feed.xml")

    assert ["application/rss+xml" <> _] = get_resp_header(conn, "content-type")
    body = response(conn, 200)
    assert body =~ ~s|<rss version="2.0">|
    assert body =~ "<title>realcomplex.systems</title>"
    assert Enum.count(FugueWeb.Updates.entries()) > 0
    assert body =~ List.first(FugueWeb.Updates.entries()).title
  end
end
