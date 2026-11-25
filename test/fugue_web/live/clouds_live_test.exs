defmodule FugueWeb.CloudsLiveTest do
  use FugueWeb.ConnCase, async: true

  test "shows the captured frame as an image, with no hook", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/clouds")

    assert has_element?(view, ~s(img[src^="/images/clouds.png"]))
    refute has_element?(view, "[phx-hook]")
  end

  test "is a still life, and says so", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/clouds")

    assert render(view) =~ "a still life rather than a simulation"
    refute render(view) =~ "Worley"
  end
end
