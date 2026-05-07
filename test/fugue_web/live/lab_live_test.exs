defmodule FugueWeb.LabLiveTest do
  use FugueWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "/lab index" do
    test "lists the lab cards", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/lab")
      assert html =~ ~s(href="/lab/gam")
      assert html =~ ~s(href="/lab/bayes")
    end
  end

  describe "/lab/gam" do
    test "renders the GAM lab and the JS hook anchor", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/lab/gam")
      assert html =~ ~s(phx-hook="LabGam")
      # House price is the initial dataset.
      assert html =~ "Floor area and sale price"
    end

    test "select_dataset switches the visible dataset", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/lab/gam")

      view
      |> element("button[phx-value-id=bay_bridge]")
      |> render_click()

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.dataset_id == "bay_bridge"

      assert render(view) =~ "Bay Bridge tolls by hour of day"
    end

    test "select_dataset is a no-op for unknown ids", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/lab/gam")
      before = :sys.get_state(view.pid).socket.assigns.dataset_id
      render_hook(view, "select_dataset", %{"id" => "not_a_real_dataset"})
      assert :sys.get_state(view.pid).socket.assigns.dataset_id == before
    end

    test "toggle_layer flips the per-dataset layer flag", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/lab/gam")

      render_hook(view, "toggle_layer", %{"layer" => "gam"})
      id = :sys.get_state(view.pid).socket.assigns.dataset_id
      assert :sys.get_state(view.pid).socket.assigns.layer_state[id]["gam"] == true

      render_hook(view, "toggle_layer", %{"layer" => "gam"})
      assert :sys.get_state(view.pid).socket.assigns.layer_state[id]["gam"] == false
    end
  end

  describe "/lab/bayes mount" do
    test "renders three sections fully server-side (no Bayes hooks)", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/lab/bayes")

      # Three sections present.
      assert html =~ "search_cell" or html =~ "phx-click=\"search_cell\""
      assert html =~ "phx-click=\"observe_year\""
      assert html =~ "phx-change=\"set_threshold\""

      # No bayes_* hooks left in the DOM after the spring-clean refactor.
      refute html =~ ~s(phx-hook="BayesSearch")
      refute html =~ ~s(phx-hook="BayesRate")
      refute html =~ ~s(phx-hook="BayesDecision")
    end

    test "search grid is a 5x5 of cells" do
      {:ok, _view, html} = live(build_conn(), "/lab/bayes")
      occurrences = html |> String.split(~s(phx-click="search_cell")) |> length()
      # n cells -> n+1 chunks. 25 clickable cells.
      assert occurrences == 25 + 1
    end
  end

  describe "/lab/bayes -- search section" do
    test "clicking the truth cell sets search_found", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/lab/bayes")
      truth = :sys.get_state(view.pid).socket.assigns.search_truth

      render_hook(view, "search_cell", %{"index" => Integer.to_string(truth)})

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.search_found == truth
      assert MapSet.member?(assigns.search_searched, truth)
    end

    test "clicking the same cell twice doesn't re-add it after a find", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/lab/bayes")
      truth = :sys.get_state(view.pid).socket.assigns.search_truth

      render_hook(view, "search_cell", %{"index" => Integer.to_string(truth)})
      before = :sys.get_state(view.pid).socket.assigns

      # Second click on a different cell after found is a no-op.
      other = rem(truth + 1, 25)
      render_hook(view, "search_cell", %{"index" => Integer.to_string(other)})
      after_ = :sys.get_state(view.pid).socket.assigns

      assert before.search_found == after_.search_found
      assert before.search_searched == after_.search_searched
    end

    test "reset_search clears searched cells and re-rolls truth in [0, 24]", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/lab/bayes")

      render_hook(view, "search_cell", %{"index" => "0"})
      render_hook(view, "reset_search", %{})

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.search_found == nil
      assert MapSet.size(assigns.search_searched) == 0
      assert assigns.search_truth in 0..24
    end
  end

  describe "/lab/bayes -- rate section" do
    test "observe_year increments year count and accumulates observations", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/lab/bayes")

      for _ <- 1..3, do: render_hook(view, "observe_year", %{})

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.observed_years == 3
      assert length(assigns.observation_log) == 3
      assert Enum.all?(assigns.observation_log, &(is_integer(&1) and &1 >= 0))
      assert assigns.observed_count == Enum.sum(assigns.observation_log)
    end

    test "reset_rate zeroes the accumulators", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/lab/bayes")

      render_hook(view, "observe_year", %{})
      render_hook(view, "reset_rate", %{})

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.observed_years == 0
      assert assigns.observed_count == 0
      assert assigns.observation_log == []
    end
  end

  describe "/lab/bayes -- decision section" do
    test "set_threshold parses and clamps the slider value", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/lab/bayes")

      render_hook(view, "set_threshold", %{"value" => "3.7"})
      assert :sys.get_state(view.pid).socket.assigns.decision_threshold == 3.7

      # Above the max clamps down.
      render_hook(view, "set_threshold", %{"value" => "999"})
      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.decision_threshold == assigns.threshold_max

      # Below the min clamps up.
      render_hook(view, "set_threshold", %{"value" => "-1"})
      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.decision_threshold == assigns.threshold_min
    end

    test "set_threshold ignores unparseable input", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/lab/bayes")
      before = :sys.get_state(view.pid).socket.assigns.decision_threshold

      render_hook(view, "set_threshold", %{"value" => "not-a-number"})
      assert :sys.get_state(view.pid).socket.assigns.decision_threshold == before
    end
  end
end
