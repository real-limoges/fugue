defmodule FugueWeb.ErrorHTMLTest do
  use FugueWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template, only: [render_to_string: 4]

  test "renders 404.html naming the missing path" do
    html =
      render_to_string(FugueWeb.ErrorHTML, "404", "html", conn: build_conn(:get, "/nowhere"))

    assert html =~ "Not found."
    assert html =~ "/nowhere"
    assert html =~ ~s(href="/")
  end

  test "renders 500.html" do
    html = render_to_string(FugueWeb.ErrorHTML, "500", "html", conn: build_conn())

    assert html =~ "Something broke."
  end

  test "other statuses fall back to the bare status message" do
    assert render_to_string(FugueWeb.ErrorHTML, "400", "html", []) == "Bad Request"
  end

  test "an unknown route gets the 404 page inside the site chrome", %{conn: conn} do
    body = conn |> get("/no-such-page") |> html_response(404)

    assert body =~ "Not found."
    assert body =~ "/no-such-page"
    # The root layout wraps it: header nav and footer are both there.
    assert body =~ ~s(href="/mood")
    assert body =~ ~s(href="/about")
  end
end
