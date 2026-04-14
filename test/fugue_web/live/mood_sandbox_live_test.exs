defmodule FugueWeb.MoodSandboxLiveTest do
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

      {:ok, view, _html} = live(conn, "/mood-sandbox")
      html = render(view)

      assert html =~ "Mood Sandbox"
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

      {:ok, view, _html} = live(conn, "/mood-sandbox")
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

      {:ok, view, _html} = live(conn, "/mood-sandbox")

      html = render(view)
      assert html =~ "Could not connect to Ish API"

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.loading == false
      assert assigns.error =~ "Could not connect"
    end
  end

  describe "slider bounds" do
    test "renders max k=5 and max m=3.0", %{conn: conn} do
      stub_all_endpoints()

      {:ok, view, _html} = live(conn, "/mood-sandbox")
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

      {:ok, view, _html} = live(conn, "/mood-sandbox")

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

      {:ok, view, _html} = live(conn, "/mood-sandbox")

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

      {:ok, view, _html} = live(conn, "/mood-sandbox")

      render_hook(view, "mf_suggest", %{})

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.suggestion == IshFixtures.suggested_membership_defs()
    end
  end

  describe "mf_apply_suggestion event" do
    test "is a no-op when no suggestion is set", %{conn: conn} do
      stub_all_endpoints()

      {:ok, view, _html} = live(conn, "/mood-sandbox")

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

      {:ok, view, _html} = live(conn, "/mood-sandbox")

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

      {:ok, view, _html} = live(conn, "/mood-sandbox")

      render_hook(view, "mf_reset", %{})

      assert :counters.get(post_count, 1) == 1
      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.membership_defs == IshFixtures.membership_defs()
      assert assigns.suggestion == nil
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
