defmodule FugueWeb.MoodLiveTest do
  use FugueWeb.ConnCase, async: false

  alias Fugue.{IshCache, IshFixtures}

  setup %{conn: conn} do
    Req.Test.set_req_test_to_shared()
    IshCache.invalidate_all()
    %{conn: conn}
  end

  describe "mount" do
    test "renders past the loading state when Ish is available", %{conn: conn} do
      stub_ish()

      {:ok, view, _html} = live(conn, "/mood")
      html = render(view)

      refute html =~ "Loading mood data"

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.loading == false
      assert assigns.error == nil
      assert assigns.entries != []
      assert assigns.analysis.clusters != []
    end

    test "renders an error banner when Ish is unreachable", %{conn: conn} do
      Req.Test.stub(Fugue.Ish, fn conn -> Plug.Conn.send_resp(conn, 500, "boom") end)

      {:ok, view, _html} = live(conn, "/mood")
      html = render(view)

      assert html =~ "Could not connect to Ish API"

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.loading == false
      assert assigns.error =~ "Could not connect"
    end
  end

  # -- helpers --

  defp stub_ish do
    Req.Test.stub(Fugue.Ish, fn conn ->
      case {conn.method, conn.request_path} do
        {"GET", "/data"} -> Req.Test.json(conn, IshFixtures.entries())
        {"POST", "/cluster"} -> Req.Test.json(conn, IshFixtures.cluster_response(3))
        {"GET", "/gaps"} -> Req.Test.json(conn, IshFixtures.gaps_response())
        _ -> Plug.Conn.send_resp(conn, 404, "unmatched")
      end
    end)
  end
end
