defmodule FugueWeb.ColorLiveTest do
  use FugueWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "/color mounts and renders the personal opener", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/color")
    # Personal-tour hook: chapter opens with the narrator's colorblindness.
    assert html =~ "colorblind" or html =~ "protanop"
  end

  test "all seven section anchors are present", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/color")
    # Sections use semantic ids (light, eye, metamerism, gamut, language, remainder, closer).
    for id <- ~w(light eye metamerism gamut language remainder closer) do
      assert html =~ ~s(id="#{id}"), "missing section anchor id=#{id}"
    end
  end
end
