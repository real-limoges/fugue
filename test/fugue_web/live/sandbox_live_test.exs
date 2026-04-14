defmodule FugueWeb.SandboxLiveTest do
  use FugueWeb.ConnCase, async: false

  alias Fugue.{IshCache, IshFixtures, MembershipDefaults}

  @defaults_key {MembershipDefaults, :snapshot}

  setup %{conn: conn} do
    Req.Test.set_req_test_to_shared()
    IshCache.invalidate_all()
    :persistent_term.erase(@defaults_key)

    on_exit(fn ->
      :persistent_term.erase(@defaults_key)
    end)

    %{conn: conn}
  end

  describe "mount and load_all" do
    test "renders past the loading state with populated assigns", %{conn: conn} do
      stub_all_endpoints()

      {:ok, view, _html} = live(conn, "/sandbox")
      html = render(view)

      assert html =~ "Fuzzy Sandbox"
      refute html =~ "Loading sandbox"

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.loading == false
      assert assigns.error == nil
      assert assigns.analysis.clusters != []
      assert assigns.membership_defs != nil
      assert map_size(assigns.histograms) == 5
    end

    test "renders the descriptive cluster name chips after load", %{conn: conn} do
      stub_all_endpoints()

      {:ok, view, _html} = live(conn, "/sandbox")
      html = render(view)

      assigns = :sys.get_state(view.pid).socket.assigns
      names = Enum.map(assigns.analysis.clusters, & &1["name"])
      assert names != []

      # Generated names can include `&` which is HTML-escaped; assert each word.
      Enum.each(names, fn name ->
        name
        |> String.split([" & ", " "])
        |> Enum.reject(&(&1 == ""))
        |> Enum.each(fn token -> assert html =~ token end)
      end)
    end

    test "shows an error banner when Ish is unreachable", %{conn: conn} do
      Req.Test.stub(Fugue.Ish, fn conn -> Plug.Conn.send_resp(conn, 500, "boom") end)

      {:ok, view, _html} = live(conn, "/sandbox")

      html = render(view)
      assert html =~ "Could not connect to Ish API"

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.loading == false
      assert assigns.error =~ "Could not connect"
    end
  end

  describe "downstream effects section" do
    test "renders the FPC gauge with the formatted value and bar", %{conn: conn} do
      stub_all_endpoints()

      {:ok, view, _html} = live(conn, "/sandbox")
      html = render(view)

      assert html =~ "Cluster crispness (FPC)"
      # Fixture sets fpc: 0.842
      assert html =~ "0.842"
      # Floor label for k=3
      assert html =~ "floor 1/k = 0.333"
      # Bar element is present
      assert html =~ ~s(class="h-full bg-amber-400)
    end

    test "renders a ClusterStream hook instead of the calendar", %{conn: conn} do
      stub_all_endpoints()

      {:ok, view, _html} = live(conn, "/sandbox")
      html = render(view)

      assert html =~ ~s(id="sandbox-cluster-stream")
      assert html =~ ~s(phx-hook="ClusterStream")
      refute html =~ ~s(id="sandbox-calendar")
    end

    test "renders a back-link to /mood", %{conn: conn} do
      stub_all_endpoints()

      {:ok, view, _html} = live(conn, "/sandbox")
      html = render(view)

      assert html =~ ~s(href="/mood")
      assert html =~ "Back to /mood"
    end
  end

  describe "slider bounds" do
    test "renders max k=5 and max m=3.0", %{conn: conn} do
      stub_all_endpoints()

      {:ok, view, _html} = live(conn, "/sandbox")
      html = render(view)

      assert html =~ ~s(name="k")
      assert html =~ ~s(max="5")
      assert html =~ ~s(name="m")
      assert html =~ ~s(max="3.0")
    end
  end

  describe "update_params event" do
    test "updates k and m and triggers reclustering", %{conn: conn} do
      call_count = :counters.new(1, [])

      Req.Test.stub(Fugue.Ish, fn conn ->
        case {conn.method, conn.request_path} do
          {"POST", "/cluster"} ->
            :counters.add(call_count, 1, 1)
            Req.Test.json(conn, IshFixtures.cluster_response(3))

          _ ->
            route_non_cluster(conn)
        end
      end)

      {:ok, view, _html} = live(conn, "/sandbox")

      # Force the LV to drain its mailbox so :load_all runs before we check.
      _ = :sys.get_state(view.pid)

      # First call during load_all.
      assert :counters.get(call_count, 1) == 1

      view
      |> element("form[phx-change=update_params]")
      |> render_change(%{"k" => "4", "m" => "2.0"})

      assert :counters.get(call_count, 1) == 2

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.k == 4
      assert assigns.m == 2.0
    end
  end

  describe "mf_commit event" do
    test "posts updated defs to Ish, invalidates cache, and re-clusters", %{conn: conn} do
      updates = :counters.new(1, [])

      Req.Test.stub(Fugue.Ish, fn conn ->
        case {conn.method, conn.request_path} do
          {"POST", "/membership-functions"} ->
            :counters.add(updates, 1, 1)
            Req.Test.json(conn, IshFixtures.membership_defs())

          _ ->
            route_non_cluster(conn) || route_cluster(conn)
        end
      end)

      {:ok, view, _html} = live(conn, "/sandbox")

      render_hook(view, "mf_commit", %{"inputs" => IshFixtures.membership_defs()["inputs"]})

      assert :counters.get(updates, 1) == 1
      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.suggestion == nil
    end
  end

  describe "mf_suggest event" do
    test "stores the suggestion in assigns", %{conn: conn} do
      Req.Test.stub(Fugue.Ish, fn conn ->
        case {conn.method, conn.request_path} do
          {"POST", "/membership-functions/suggest"} ->
            Req.Test.json(conn, IshFixtures.suggested_membership_defs())

          _ ->
            route_non_cluster(conn) || route_cluster(conn)
        end
      end)

      {:ok, view, _html} = live(conn, "/sandbox")

      render_hook(view, "mf_suggest", %{})

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.suggestion == IshFixtures.suggested_membership_defs()
    end
  end

  describe "mf_apply_suggestion event" do
    test "is a no-op when no suggestion is set", %{conn: conn} do
      stub_all_endpoints()

      {:ok, view, _html} = live(conn, "/sandbox")

      before = :sys.get_state(view.pid).socket.assigns.membership_defs
      render_hook(view, "mf_apply_suggestion", %{})

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.membership_defs == before
      assert assigns.suggestion == nil
    end

    test "pushes the suggestion to Ish and clears it", %{conn: conn} do
      Req.Test.stub(Fugue.Ish, fn conn ->
        case {conn.method, conn.request_path} do
          {"POST", "/membership-functions/suggest"} ->
            Req.Test.json(conn, IshFixtures.suggested_membership_defs())

          {"POST", "/membership-functions"} ->
            Req.Test.json(conn, IshFixtures.suggested_membership_defs())

          _ ->
            route_non_cluster(conn) || route_cluster(conn)
        end
      end)

      {:ok, view, _html} = live(conn, "/sandbox")

      render_hook(view, "mf_suggest", %{})
      assert :sys.get_state(view.pid).socket.assigns.suggestion != nil

      render_hook(view, "mf_apply_suggestion", %{})

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.suggestion == nil
      assert assigns.membership_defs == IshFixtures.suggested_membership_defs()
    end
  end

  describe "mf_reset event" do
    test "restores the MembershipDefaults snapshot and re-clusters", %{conn: conn} do
      # Pre-populate the defaults snapshot with the original defs.
      :persistent_term.put(@defaults_key, IshFixtures.membership_defs())

      post_count = :counters.new(1, [])

      Req.Test.stub(Fugue.Ish, fn conn ->
        case {conn.method, conn.request_path} do
          {"POST", "/membership-functions"} ->
            :counters.add(post_count, 1, 1)
            Req.Test.json(conn, IshFixtures.membership_defs())

          _ ->
            route_non_cluster(conn) || route_cluster(conn)
        end
      end)

      {:ok, view, _html} = live(conn, "/sandbox")

      render_hook(view, "mf_reset", %{})

      assert :counters.get(post_count, 1) == 1
      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.membership_defs == IshFixtures.membership_defs()
      assert assigns.suggestion == nil
    end
  end

  describe "apply_preset event" do
    test "conservative sets k=2, m=1.2 and pushes new MF to Ish", %{conn: conn} do
      post_count = :counters.new(1, [])

      Req.Test.stub(Fugue.Ish, fn conn ->
        case {conn.method, conn.request_path} do
          {"POST", "/membership-functions"} ->
            :counters.add(post_count, 1, 1)
            Req.Test.json(conn, IshFixtures.membership_defs())

          _ ->
            route_non_cluster(conn) || route_cluster(conn)
        end
      end)

      {:ok, view, _html} = live(conn, "/sandbox")
      render_hook(view, "apply_preset", %{"name" => "conservative"})

      assert :counters.get(post_count, 1) == 1
      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.k == 2
      assert assigns.m == 1.2
      assert length(assigns.history) == 1
    end

    test "aggressive sets k=5, m=1.8", %{conn: conn} do
      stub_all_endpoints()
      {:ok, view, _html} = live(conn, "/sandbox")
      render_hook(view, "apply_preset", %{"name" => "aggressive"})

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.k == 5
      assert assigns.m == 1.8
    end

    test "chaos sets k=5, m=2.8", %{conn: conn} do
      stub_all_endpoints()
      {:ok, view, _html} = live(conn, "/sandbox")
      render_hook(view, "apply_preset", %{"name" => "chaos"})

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.k == 5
      assert assigns.m == 2.8
    end

    test "randomize produces valid k in 2..5", %{conn: conn} do
      stub_all_endpoints()
      {:ok, view, _html} = live(conn, "/sandbox")
      render_hook(view, "apply_preset", %{"name" => "randomize"})

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.k in 2..5
      assert assigns.m >= 1.2
      assert assigns.m <= 2.6
    end
  end

  describe "undo event" do
    test "is a no-op with empty history and does not POST to Ish", %{conn: conn} do
      post_count = :counters.new(1, [])

      Req.Test.stub(Fugue.Ish, fn conn ->
        case {conn.method, conn.request_path} do
          {"POST", "/membership-functions"} ->
            :counters.add(post_count, 1, 1)
            Req.Test.json(conn, IshFixtures.membership_defs())

          _ ->
            route_non_cluster(conn) || route_cluster(conn)
        end
      end)

      {:ok, view, _html} = live(conn, "/sandbox")
      render_hook(view, "undo", %{})

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.history == []
      assert :counters.get(post_count, 1) == 0
    end

    test "restores previous k and m after update_params", %{conn: conn} do
      stub_all_endpoints()
      {:ok, view, _html} = live(conn, "/sandbox")

      view
      |> element("form[phx-change=update_params]")
      |> render_change(%{"k" => "4", "m" => "2.1"})

      mid = :sys.get_state(view.pid).socket.assigns
      assert mid.k == 4
      assert mid.m == 2.1
      assert length(mid.history) == 1

      render_hook(view, "undo", %{})

      restored = :sys.get_state(view.pid).socket.assigns
      assert restored.k == 3
      assert restored.m == 1.5
      assert restored.history == []
    end

    test "restores state after apply_preset", %{conn: conn} do
      stub_all_endpoints()
      {:ok, view, _html} = live(conn, "/sandbox")

      render_hook(view, "apply_preset", %{"name" => "chaos"})
      mid = :sys.get_state(view.pid).socket.assigns
      assert mid.k == 5
      assert mid.m == 2.8

      render_hook(view, "undo", %{})
      restored = :sys.get_state(view.pid).socket.assigns
      assert restored.k == 3
      assert restored.m == 1.5
    end
  end

  # -- helpers --

  defp stub_all_endpoints do
    Req.Test.stub(Fugue.Ish, fn conn ->
      route_non_cluster(conn) || route_cluster(conn) || route_mf(conn) || not_found(conn)
    end)
  end

  defp route_non_cluster(conn) do
    case {conn.method, conn.request_path} do
      {"GET", "/data"} -> Req.Test.json(conn, IshFixtures.entries())
      {"GET", "/gaps"} -> Req.Test.json(conn, IshFixtures.gaps_response())
      {"GET", "/membership-functions"} -> Req.Test.json(conn, IshFixtures.membership_defs())
      _ -> nil
    end
  end

  defp route_cluster(conn) do
    case {conn.method, conn.request_path} do
      {"POST", "/cluster"} -> Req.Test.json(conn, IshFixtures.cluster_response(3))
      _ -> nil
    end
  end

  defp route_mf(conn) do
    case {conn.method, conn.request_path} do
      {"POST", "/membership-functions"} ->
        Req.Test.json(conn, IshFixtures.membership_defs())

      {"POST", "/membership-functions/suggest"} ->
        Req.Test.json(conn, IshFixtures.suggested_membership_defs())

      _ ->
        nil
    end
  end

  defp not_found(conn), do: Plug.Conn.send_resp(conn, 404, "unmatched")
end
