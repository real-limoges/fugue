defmodule FugueWeb.BlogControllerTest do
  use FugueWeb.ConnCase

  describe "GET /blog" do
    test "renders blog index", %{conn: conn} do
      conn = get(conn, "/blog")
      assert html_response(conn, 200) =~ "Blog"
      assert html_response(conn, 200) =~ "Hello World"
    end

    test "filters by tag", %{conn: conn} do
      conn = get(conn, "/blog?tag=meta")
      assert html_response(conn, 200) =~ "Hello World"
    end

    test "shows empty results for unknown tag", %{conn: conn} do
      conn = get(conn, "/blog?tag=nonexistent")
      response = html_response(conn, 200)
      assert response =~ "Blog"
      refute response =~ "Hello World"
    end
  end

  describe "GET /blog/:slug" do
    test "renders a blog post", %{conn: conn} do
      conn = get(conn, "/blog/hello-world")
      response = html_response(conn, 200)
      assert response =~ "Hello World"
      assert response =~ "hello from a code block"
    end

    test "returns 404 for unknown slug", %{conn: conn} do
      conn = get(conn, "/blog/does-not-exist")
      assert html_response(conn, 404)
    end
  end

  describe "GET /blog/feed.xml" do
    test "renders Atom feed", %{conn: conn} do
      conn = get(conn, "/blog/feed.xml")
      response = response(conn, 200)
      assert response_content_type(conn, :xml)
      assert response =~ "<feed"
      assert response =~ "Hello World"
    end
  end
end
