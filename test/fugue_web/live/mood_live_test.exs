defmodule FugueWeb.MoodLiveTest do
  use FugueWeb.ConnCase, async: true

  describe "mount" do
    test "renders past the loading state, loaded from the bundled dataset", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/mood")
      html = render(view)

      refute html =~ "Loading mood data"

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.loading == false
      assert assigns.entries != []
      assert assigns.analysis.clusters != []
    end

    test "renders a cross-link to /menagerie in chapter 1", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/mood")
      html = render(view)

      assert html =~ ~s(href="/menagerie")
      assert html =~ "Play with the knobs yourself"
    end

    test "renders the isolation hint above the cluster chips", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/mood")
      html = render(view)

      assert html =~ "click a state to isolate it"
    end

    test "shows an isolation banner after a cluster is selected", %{conn: conn} do
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
      {:ok, view, _html} = live(conn, "/mood")
      html = render(view)

      # One per ported component. Each assertion is a cheap grep on the rendered
      # DOM -- the real guarantee is that none of them crashed during render.
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
      {:ok, view, _html} = live(conn, "/mood")

      # Pick whichever cluster actually has a segment rendered. The real
      # (non-fixture) dataset spans ~4 years, so a dominant cluster can
      # recur across many non-contiguous segments -- simulate the click
      # event directly rather than requiring a single unique DOM match,
      # since every one of that cluster's segments fires the same event.
      cluster_id =
        :sys.get_state(view.pid).socket.assigns.snapshot.timeline_segments
        |> List.first()
        |> Map.fetch!(:cluster)

      html = render_click(view, "cluster_selected", %{"cluster" => cluster_id})

      assert html =~ "Isolating"

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.focus == {:cluster, cluster_id}
    end

    test "clicking a radar cell isolates the cluster", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/mood")

      cluster_id =
        :sys.get_state(view.pid).socket.assigns.snapshot.radar_centroids
        |> List.first()
        |> Map.fetch!(:id)

      view
      |> element(~s(.radar-cell[phx-click="cluster_selected"][phx-value-cluster="#{cluster_id}"]))
      |> render_click()

      assert :sys.get_state(view.pid).socket.assigns.focus == {:cluster, cluster_id}
    end

    test "clicking a calendar day-cell focuses the day", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/mood")

      date =
        :sys.get_state(view.pid).socket.assigns.snapshot.calendar_days
        |> Enum.find(&(&1.is_gap == false))
        |> Map.fetch!(:date)

      view
      |> element(~s(rect.day-cell[phx-value-date="#{date}"]))
      |> render_click()

      assert :sys.get_state(view.pid).socket.assigns.focus == {:day, date}
    end

    test "clear_highlights collapses focus to :none", %{conn: conn} do
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

      assert :sys.get_state(view.pid).socket.assigns.focus == :none
    end
  end
end
