defmodule FugueWeb.CloudsLiveTest do
  use FugueWeb.ConnCase, async: true

  test "mounts the canvas for the CloudsCanvas hook", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/clouds")

    assert has_element?(view, "canvas#clouds-canvas[phx-hook=CloudsCanvas]")
  end

  test "is a still life, and says so", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/clouds")

    assert render(view) =~ "a still life rather than a simulation"
    refute render(view) =~ "Worley"
  end
end
