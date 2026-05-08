defmodule FugueWeb.MenagerieLiveTest do
  use FugueWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Fugue.IshFixtures

  describe "index" do
    test "lists the experiments and links to their pages", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/menagerie")

      assert html =~ ">Math playgrounds</h1>"
      assert html =~ "Fuzzy logic"
      assert html =~ "Boids playground"
      assert html =~ "Mamdani fan controller"
      assert html =~ "Classical vs quantum walk"
      assert html =~ "Three ways to count"
      assert html =~ "Abelian sandpile"
      assert html =~ ~s(href="/menagerie/fuzzy")
      assert html =~ ~s(href="/menagerie/mamdani")
      assert html =~ ~s(href="/menagerie/boids")
      assert html =~ ~s(href="/menagerie/quantum-walk")
      assert html =~ ~s(href="/menagerie/quantum-stats")
      assert html =~ ~s(href="/menagerie/sandpile")
    end
  end

  describe "mount /menagerie/fuzzy" do
    test "renders the temperature bands experiment", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/menagerie/fuzzy")

      assert html =~ "Fuzzy temperature bands"
      assert html =~ "cold"
      assert html =~ "cool"
      assert html =~ "mild"
      assert html =~ "warm"
      assert html =~ "hot"
      assert html =~ ~s(phx-hook="BandsHover")
      refute html =~ "Fuzzy clustering"
      refute html =~ "Mamdani fan controller"
    end

    test "initializes params to defaults", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/menagerie/fuzzy")

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.center_offset == 0.0
      assert assigns.spread == 1.0
      assert length(assigns.mfs) == 5
      assert Enum.map(assigns.mfs, & &1.name) == ~w(cold cool mild warm hot)
    end

    test "renders a Melbourne date range from the bundled CSV", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/menagerie/fuzzy")

      assert html =~ "Melbourne Airport"
      assert html =~ ~r/20\d\d-\d\d-\d\d/
    end

    test "server-renders the bands SVG with per-day JSON for the hover hook", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/menagerie/fuzzy")

      # Shapes panel (MF triangle outlines).
      assert html =~ ~s(class="stream-svg) or html =~ ~s(id="temperature-bands")
      # Stacked band paths -- one per fuzzy set.
      assert html =~ ~s(class="band")
      # Crosshair line carrying the bands-crosshair class.
      assert html =~ "bands-crosshair"
      # data-series is the per-day JSON payload BandsHover uses on hover.
      assert html =~ "data-series="
      # Should contain a date from the bundled CSV range.
      # data-series is an attribute value, so quotes are HTML-escaped.
      assert html =~ ~r/date&quot;:&quot;20\d\d-\d\d-\d\d&quot;/
    end

    test "changing spread re-renders bands with an updated series", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/menagerie/fuzzy")

      before_html = render(view)

      view
      |> element("form[phx-change=update_fuzzy_params]")
      |> render_change(%{"center_offset" => "0.0", "spread" => "1.8"})

      after_html = render(view)
      refute before_html == after_html

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.bands_series != []
      assert length(assigns.bands_shapes) == 5
    end
  end

  describe "mount /menagerie/mamdani" do
    test "renders the Mamdani fan controller experiment", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/menagerie/mamdani")

      assert html =~ "Mamdani fan controller"
      assert html =~ "temperature"
      assert html =~ "humidity"
      assert html =~ ~s(phx-hook="MamdaniPlayground")
      assert html =~ ~s(phx-change="update_mamdani_inputs")
      refute html =~ "Fuzzy temperature bands"
    end

    test "defaults Mamdani inputs to the fixture's starting values", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/menagerie/mamdani")

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.mamdani_temperature == 22.0
      assert assigns.mamdani_humidity == 50.0
      assert assigns.mamdani_response == nil
      assert assigns.mamdani_error == nil
    end
  end

  describe "update_fuzzy_params event" do
    test "center_offset shifts every MF peak", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/menagerie/fuzzy")

      view
      |> element("form[phx-change=update_fuzzy_params]")
      |> render_change(%{"center_offset" => "2.5", "spread" => "1.0"})

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.center_offset == 2.5

      peaks = Enum.map(assigns.mfs, & &1.b)
      assert peaks == [12.5, 19.5, 26.5, 33.5, 40.5]
    end

    test "spread widens the triangle half-widths", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/menagerie/fuzzy")

      view
      |> element("form[phx-change=update_fuzzy_params]")
      |> render_change(%{"center_offset" => "0.0", "spread" => "1.5"})

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.spread == 1.5

      cold = List.first(assigns.mfs)
      assert_in_delta(cold.a, -0.5, 0.001)
      assert cold.b == 10.0
      assert_in_delta(cold.c, 20.5, 0.001)
    end

    test "no-op when values are unchanged", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/menagerie/fuzzy")

      before = :sys.get_state(view.pid).socket.assigns.mfs

      view
      |> element("form[phx-change=update_fuzzy_params]")
      |> render_change(%{"center_offset" => "0.0", "spread" => "1.0"})

      after_ = :sys.get_state(view.pid).socket.assigns.mfs
      assert before == after_
    end
  end

  describe "Mamdani playground" do
    test "menagerie:mamdani_ready stores the inference response and clears error",
         %{conn: conn} do
      stub_mamdani()

      {:ok, view, _html} = live(conn, "/menagerie/mamdani")
      render_hook(view, "menagerie:mamdani_ready", %{})

      # Wait for the async Task to deliver :mamdani_result
      Process.sleep(200)
      _ = render(view)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.mamdani_response == IshFixtures.mamdani_response()
      assert assigns.mamdani_error == nil
    end

    test "update_mamdani_inputs reassigns inputs and refreshes the response",
         %{conn: conn} do
      stub_mamdani()

      {:ok, view, _html} = live(conn, "/menagerie/mamdani")
      render_hook(view, "menagerie:mamdani_ready", %{})

      view
      |> element("form[phx-change=update_mamdani_inputs]")
      |> render_change(%{"temperature" => "30.0", "humidity" => "75"})

      # Wait for the async Task to deliver :mamdani_result
      Process.sleep(200)
      _ = render(view)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.mamdani_temperature == 30.0
      assert assigns.mamdani_humidity == 75.0
      assert assigns.mamdani_response == IshFixtures.mamdani_response()
    end

    test "no-op when the inputs haven't moved", %{conn: conn} do
      stub_mamdani()

      {:ok, view, _html} = live(conn, "/menagerie/mamdani")
      render_hook(view, "menagerie:mamdani_ready", %{})

      before = :sys.get_state(view.pid).socket.assigns

      view
      |> element("form[phx-change=update_mamdani_inputs]")
      |> render_change(%{"temperature" => "22.0", "humidity" => "50"})

      after_ = :sys.get_state(view.pid).socket.assigns
      assert before.mamdani_temperature == after_.mamdani_temperature
      assert before.mamdani_humidity == after_.mamdani_humidity
    end

    test "surfaces an error banner when Ish is unreachable", %{conn: conn} do
      Req.Test.stub(Fugue.Ish, fn conn -> Plug.Conn.send_resp(conn, 500, "boom") end)

      {:ok, view, _html} = live(conn, "/menagerie/mamdani")
      render_hook(view, "menagerie:mamdani_ready", %{})

      # Wait for the async Task to deliver :mamdani_result
      Process.sleep(200)

      html = render(view)
      assert html =~ "inference service unavailable"

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.mamdani_error =~ "unavailable"
    end
  end

  describe "Fugue.Menagerie.Mamdani" do
    alias Fugue.Menagerie.Mamdani

    test "request/2 wraps crisp values into the wire format" do
      req = Mamdani.request(25, 40)
      assert req["values"]["temperature"] == 25.0
      assert req["values"]["humidity"] == 40.0
      assert is_list(req["rules"])
      assert length(req["rules"]) == length(Mamdani.rule_descriptions())
      assert is_list(req["mfs"]["inputs"])
      assert is_list(req["mfs"]["outputs"])
    end

    test "mfs/0 exposes two inputs and one output" do
      %{"inputs" => inputs, "outputs" => outputs} = Mamdani.mfs()
      assert Enum.map(inputs, & &1["name"]) == ["temperature", "humidity"]
      assert Enum.map(outputs, & &1["name"]) == ["fan_speed"]
    end

    test "rule_descriptions/0 matches the rule count" do
      descs = Mamdani.rule_descriptions()
      assert length(descs) == length(Mamdani.request(0, 0)["rules"])
      assert Enum.all?(descs, &is_binary/1)
    end
  end

  describe "Fugue.Menagerie.Fuzzy" do
    alias Fugue.Menagerie.Fuzzy

    test "triangular/4 peaks at 1 at the center" do
      assert Fuzzy.triangular(10.0, 5.0, 10.0, 15.0) == 1.0
    end

    test "triangular/4 ramps linearly to 0.5 at the half-way points" do
      assert Fuzzy.triangular(7.5, 5.0, 10.0, 15.0) == 0.5
      assert Fuzzy.triangular(12.5, 5.0, 10.0, 15.0) == 0.5
    end

    test "triangular/4 is zero outside [a, c]" do
      assert Fuzzy.triangular(4.0, 5.0, 10.0, 15.0) == 0.0
      assert Fuzzy.triangular(16.0, 5.0, 10.0, 15.0) == 0.0
    end

    test "memberships/2 normalize to 1 when any set fires" do
      mfs = Fuzzy.default_mfs()
      sum = 20.0 |> Fuzzy.memberships(mfs) |> Map.values() |> Enum.sum()
      assert_in_delta(sum, 1.0, 0.001)
    end

    test "memberships/2 return all zeros when x is outside every triangle" do
      mfs = Fuzzy.default_mfs()
      result = Fuzzy.memberships(-100.0, mfs)
      assert Enum.all?(Map.values(result), &(&1 == 0.0))
    end

    test "build_mfs/2 with defaults matches default_mfs/0" do
      assert Fuzzy.build_mfs(0.0, 1.0) == Fuzzy.default_mfs()
    end
  end

  defp stub_mamdani do
    Req.Test.stub(Fugue.Ish, fn conn ->
      case {conn.method, conn.request_path} do
        {"POST", "/inference/mamdani"} ->
          Req.Test.json(conn, IshFixtures.mamdani_response())

        _ ->
          Plug.Conn.send_resp(conn, 404, "not stubbed")
      end
    end)
  end

  describe "mount /menagerie/boids" do
    test "renders the boids page with the canvas hook anchor", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/menagerie/boids")
      assert html =~ ~s(phx-hook="BoidsCanvas")
      assert html =~ "Flock size"
    end

    test "preset replaces params with the named preset", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/menagerie/boids")
      render_hook(view, "preset", %{"name" => "tight_flock"})

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.params["count"] == 1200
      assert assigns.params["align_force"] == 0.06
    end

    test "reset returns params to the defaults", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/menagerie/boids")
      render_hook(view, "preset", %{"name" => "chaos"})
      render_hook(view, "reset", %{})

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.params["count"] == 1500
      assert assigns.params["max_speed"] == 3.0
    end
  end

  describe "mount /menagerie/sandpile" do
    test "renders the sandpile page with the canvas hook anchor", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/menagerie/sandpile")
      assert html =~ ~s(phx-hook="SandpileCanvas")
      assert html =~ "Abelian sandpile"
    end

    test "set_mode updates the mode param", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/menagerie/sandpile")
      render_hook(view, "set_mode", %{"mode" => "random"})
      assert :sys.get_state(view.pid).socket.assigns.params["mode"] == "random"
    end

    test "update_params clamps speed to the configured bounds", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/menagerie/sandpile")

      view
      |> element("form[phx-change=update_params]")
      |> render_change(%{"speed" => "9999"})

      assert :sys.get_state(view.pid).socket.assigns.params["speed"] == 200

      view
      |> element("form[phx-change=update_params]")
      |> render_change(%{"speed" => "0"})

      assert :sys.get_state(view.pid).socket.assigns.params["speed"] == 1
    end
  end

  describe "mount /menagerie/quantum-walk" do
    test "renders the quantum walk page with the canvas hook anchor", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/menagerie/quantum-walk")
      assert html =~ ~s(phx-hook="QuantumWalk")
      assert html =~ "Classical vs quantum walk"
    end

    test "update_params parses steps + decoherence", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/menagerie/quantum-walk")

      view
      |> element("form[phx-change=update_params]")
      |> render_change(%{"steps" => "120", "decoherence" => "0.5"})

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.params["steps"] == 120
      assert assigns.params["decoherence"] == 0.5
    end

    test "reset returns params to defaults", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/menagerie/quantum-walk")

      view
      |> element("form[phx-change=update_params]")
      |> render_change(%{"steps" => "120", "decoherence" => "0.5"})

      render_hook(view, "reset", %{})

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.params == %{"steps" => 80, "decoherence" => 0.0}
    end
  end

  describe "mount /menagerie/quantum-stats" do
    test "renders the quantum stats page with the canvas hook anchor", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/menagerie/quantum-stats")
      assert html =~ ~s(phx-hook="QuantumStats")
      assert html =~ "Three ways to count"
    end

    test "update_params parses log_temperature + particles", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/menagerie/quantum-stats")

      view
      |> element("form[phx-change=update_params]")
      |> render_change(%{"log_temperature" => "1.0", "particles" => "20"})

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.params["log_temperature"] == 1.0
      assert assigns.params["particles"] == 20
    end

    test "out-of-range slider input clamps to bounds", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/menagerie/quantum-stats")

      view
      |> element("form[phx-change=update_params]")
      |> render_change(%{"log_temperature" => "5.0", "particles" => "999"})

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.params["log_temperature"] == 1.3
      assert assigns.params["particles"] == 25
    end

    test "reset returns params to defaults", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/menagerie/quantum-stats")
      render_hook(view, "reset", %{})

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.params == %{"log_temperature" => 0.0, "particles" => 18}
    end
  end

  describe "Fugue.Menagerie.MelbourneWeather" do
    alias Fugue.Menagerie.MelbourneWeather

    test "count/0 matches length of rows/0" do
      assert MelbourneWeather.count() == length(MelbourneWeather.rows())
      assert MelbourneWeather.count() > 1500
    end

    test "every row has a date string" do
      Enum.each(MelbourneWeather.rows(), fn row ->
        assert is_binary(row.date)
        assert row.date =~ ~r/^\d{4}-\d{2}-\d{2}$/
      end)
    end

    test "date_range/0 returns first and last dates" do
      {first, last} = MelbourneWeather.date_range()
      assert first < last
    end
  end
end
