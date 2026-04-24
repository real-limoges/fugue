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

    test "renders a cross-link to /menagerie in chapter 1", %{conn: conn} do
      stub_ish()

      {:ok, view, _html} = live(conn, "/mood")
      html = render(view)

      assert html =~ ~s(href="/menagerie")
      assert html =~ "Play with the knobs yourself"
    end

    test "renders the isolation hint above the cluster chips", %{conn: conn} do
      stub_ish()

      {:ok, view, _html} = live(conn, "/mood")
      html = render(view)

      assert html =~ "click a state to isolate it"
    end

    test "shows an isolation banner after a cluster is selected", %{conn: conn} do
      stub_ish()

      {:ok, view, _html} = live(conn, "/mood")

      # Pick the first cluster id from the loaded analysis.
      cluster_id =
        :sys.get_state(view.pid).socket.assigns.analysis.clusters
        |> List.first()
        |> Map.fetch!("id")

      html =
        view
        |> element(
          ~s(button.rounded-full[phx-click="cluster_selected"][phx-value-cluster="#{cluster_id}"])
        )
        |> render_click()

      assert html =~ "Isolating"
    end

    test "every ported chapter component renders its server-side SVG", %{conn: conn} do
      stub_ish()

      {:ok, view, _html} = live(conn, "/mood")
      html = render(view)

      # One per ported component. Each assertion is a cheap grep on the rendered
      # DOM — the real guarantee is that none of them crashed during render.
      assert html =~ ~s(id="mood-experience")
      assert html =~ ~s(id="mood-trajectory")
      assert html =~ "#traj-glow"
      assert html =~ ~s(class="calendar-svg)
      assert html =~ "day-cell"
      assert html =~ ~s(id="gap-hatch")
      assert html =~ ~s(class="stream-svg)
      assert html =~ "stream-layer"
      assert html =~ "stream-legend-item"
      assert html =~ ~s(class="radar-grid")
      assert html =~ "radar-cell"
      assert html =~ ~s(id="ambiguity-histogram")
      assert html =~ ~s(id="transition-timeline")
      assert html =~ "tl-segment"
      assert html =~ ~s(id="transition-sankey")
      assert html =~ "sankey-link"
      assert html =~ "sankey-node"
      assert html =~ ~s(id="season-ring")
      assert html =~ "season-arc"
      assert html =~ ~s(id="dimension-drift")
      assert html =~ ~s(id="mood-flowers")
      assert html =~ "flower-cell"
      assert html =~ ~s(id="dimension-distributions")
      assert html =~ ~s(id="gap-breath-timeline")
    end

    test "clicking a transition-timeline segment isolates the cluster", %{conn: conn} do
      stub_ish()

      {:ok, view, _html} = live(conn, "/mood")

      # Pick whichever cluster actually has a segment rendered.
      cluster_id =
        :sys.get_state(view.pid).socket.assigns.timeline_segments
        |> List.first()
        |> Map.fetch!(:cluster)

      html =
        view
        |> element(
          ~s(.tl-segment[phx-click="cluster_selected"][phx-value-cluster="#{cluster_id}"])
        )
        |> render_click()

      assert html =~ "Isolating"

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.selected_cluster == cluster_id
    end

    test "clicking a radar cell isolates the cluster", %{conn: conn} do
      stub_ish()

      {:ok, view, _html} = live(conn, "/mood")

      cluster_id =
        :sys.get_state(view.pid).socket.assigns.radar_centroids
        |> List.first()
        |> Map.fetch!(:id)

      view
      |> element(~s(.radar-cell[phx-click="cluster_selected"][phx-value-cluster="#{cluster_id}"]))
      |> render_click()

      assert :sys.get_state(view.pid).socket.assigns.selected_cluster == cluster_id
    end

    test "clicking a calendar day-cell selects the day and highlights it", %{conn: conn} do
      stub_ish()

      {:ok, view, _html} = live(conn, "/mood")

      date =
        :sys.get_state(view.pid).socket.assigns.calendar_days
        |> Enum.find(&(&1.is_gap == false))
        |> Map.fetch!(:date)

      view
      |> element(~s(rect.day-cell[phx-value-date="#{date}"]))
      |> render_click()

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.highlighted_dates == [date]
      assert assigns.selected_day != nil
      assert assigns.selected_day.date == date
    end

    test "clear_highlights resets every selection assign", %{conn: conn} do
      stub_ish()

      {:ok, view, _html} = live(conn, "/mood")

      # Prime some selection state.
      cluster_id =
        :sys.get_state(view.pid).socket.assigns.analysis.clusters
        |> List.first()
        |> Map.fetch!("id")

      view
      |> element(
        ~s(button.rounded-full[phx-click="cluster_selected"][phx-value-cluster="#{cluster_id}"])
      )
      |> render_click()

      render_click(view, "clear_highlights", %{})

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.selected_cluster == nil
      assert assigns.selected_day == nil
      assert assigns.selected_gap == nil
      assert assigns.highlighted_dates == []
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
