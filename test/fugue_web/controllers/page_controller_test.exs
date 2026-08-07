defmodule FugueWeb.PageControllerTest do
  use FugueWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Fugue"
  end

  describe "GET /code" do
    test "lists the repos that actually run the site", %{conn: conn} do
      html = conn |> get(~p"/code") |> html_response(200)

      assert html =~ "petri"
      assert html =~ "glissando"
      assert html =~ "https://github.com/real-limoges/petri"
    end

    test "does not claim Haskell services, which were inlined in #74", %{conn: conn} do
      html = conn |> get(~p"/code") |> html_response(200)

      refute html =~ "Haskell"
      refute html =~ "hazy"
      refute html =~ "ish</a>"
    end

    test "points each repo at the routes it serves", %{conn: conn} do
      html = conn |> get(~p"/code") |> html_response(200)

      assert html =~ ~s(href="/lab/gam")
      assert html =~ ~s(href="/menagerie/sandpile")
    end
  end

  test "GET /about links to the parts list", %{conn: conn} do
    html = conn |> get(~p"/about") |> html_response(200)

    assert html =~ ~s(href="/code")
    refute html =~ "Haskell services"
  end

  # /clouds stays routable for anyone holding the URL, but nothing on the
  # site should point at it. If a link comes back, it comes back on purpose.
  test "no page links to /clouds", %{conn: conn} do
    for path <- [~p"/", ~p"/about", ~p"/code"] do
      html = conn |> get(path) |> html_response(200)
      refute html =~ ~s(href="/clouds")
    end
  end
end
