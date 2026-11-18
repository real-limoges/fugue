defmodule FugueWeb.PageControllerTest do
  use FugueWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Fugue"
  end

  test "the footer links to /amigos", %{conn: conn} do
    assert conn |> get(~p"/") |> html_response(200) =~ ~s(href="/amigos")
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

  # /code tells readers every page ends with a source line; these three are
  # the controller pages, which the LiveView routes do not cover.
  test "the controller pages end with a source line", %{conn: conn} do
    for {path, target} <- [
          {~p"/", "fugue/tree/HEAD/assets/js/petri_splash.js"},
          {~p"/about", "fugue/tree/HEAD/lib/fugue_web/controllers/page_html"},
          {~p"/code", "fugue/tree/HEAD/lib/fugue_web/controllers/page_html.ex"}
        ] do
      html = conn |> get(path) |> html_response(200)
      assert html =~ target
    end
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
