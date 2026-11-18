defmodule FugueWeb.LayoutsTest do
  use FugueWeb.ConnCase, async: true

  doctest FugueWeb.Layouts

  # The header link for each section, as the root layout renders it.
  defp nav_link(html, href) do
    [link] = Regex.run(~r/<a[^>]*href="#{href}"[^>]*class="btn[^>]*>/s, html)
    link
  end

  describe "header nav" do
    test "marks the section being viewed, including pages under it", %{conn: conn} do
      html = conn |> get(~p"/menagerie/boids") |> html_response(200)

      assert nav_link(html, "/menagerie") =~ ~s(aria-current="page")
      refute nav_link(html, "/mood") =~ "aria-current"
      refute nav_link(html, "/color") =~ "aria-current"
    end

    test "marks nothing on a page outside the nav", %{conn: conn} do
      html = conn |> get(~p"/about") |> html_response(200)

      refute html =~ ~s(aria-current="page")
    end
  end

  describe "root layout" do
    test "has a skip link to the main region", %{conn: conn} do
      html = conn |> get(~p"/code") |> html_response(200)

      assert html =~ ~s(href="#main")
      assert html =~ ~r/<main[^>]*id="main"/s
    end

    test "carries the link-preview and theme-color meta", %{conn: conn} do
      html = conn |> get(~p"/code") |> html_response(200)

      assert html =~ ~s(<meta property="og:url" content="#{FugueWeb.Endpoint.url()}/code")
      assert html =~ ~s(<link rel="canonical" href="#{FugueWeb.Endpoint.url()}/code")
      assert html =~ ~s(<meta property="og:type" content="website")
      assert html =~ ~s(data-dark="#140d20")
      assert html =~ ~s(data-light="#f2e9d8")
    end

    test "dates the footer from the clock, not a literal", %{conn: conn} do
      html = conn |> get(~p"/about") |> html_response(200)

      assert html =~ "&copy; #{Date.utc_today().year} realcomplex.systems"
    end

    test "renders the connection banners hidden", %{conn: conn} do
      html = conn |> get(~p"/mood") |> html_response(200)

      assert html =~ ~r/id="client-error"[^>]*class="[^"]*hidden/
      assert html =~ ~r/id="server-error"[^>]*class="[^"]*hidden/
    end
  end

  describe "web fonts" do
    test "only /amigos loads Google Fonts", %{conn: conn} do
      amigos = conn |> get(~p"/amigos") |> html_response(200)
      mood = conn |> get(~p"/mood") |> html_response(200)
      home = conn |> get(~p"/") |> html_response(200)

      assert amigos =~ "fonts.googleapis.com/css2?family=Archivo"
      refute mood =~ "fonts.googleapis.com"
      refute home =~ "fonts.googleapis.com"
    end
  end
end
