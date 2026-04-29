defmodule Fugue.IshTest do
  use ExUnit.Case, async: false

  alias Fugue.{Ish, IshCache, IshFixtures}

  setup do
    IshCache.invalidate_all()
    :ok
  end

  describe "data/0" do
    test "returns parsed entries on 200" do
      stub_ish(fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/data"
        Req.Test.json(conn, IshFixtures.entries())
      end)

      assert {:ok, entries} = Ish.data()
      assert length(entries) == 19
      assert [%{"date" => "2026-01-01"} | _] = entries
    end

    test "caches successful responses so repeat calls hit the cache" do
      counter = :counters.new(1, [])

      stub_ish(fn conn ->
        :counters.add(counter, 1, 1)
        Req.Test.json(conn, IshFixtures.entries())
      end)

      assert {:ok, _} = Ish.data()
      assert {:ok, _} = Ish.data()
      assert :counters.get(counter, 1) == 1
    end

    test "returns {:error, {status, body}} on non-2xx" do
      stub_ish(fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, ~s({"error":"boom"}))
      end)

      assert {:error, {500, %{"error" => "boom"}}} = Ish.data()
    end
  end

  describe "cluster/2" do
    test "posts correct k/m body and returns parsed response" do
      stub_ish(fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/cluster"
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert %{"k" => 3, "m" => 1.5} = Jason.decode!(body)
        Req.Test.json(conn, IshFixtures.cluster_response(3))
      end)

      assert {:ok, %{"clusters" => clusters, "membership" => _}} = Ish.cluster(3, 1.5)
      assert length(clusters) == 3
    end

    test "different (k, m) pairs are cached independently" do
      counter = :counters.new(1, [])

      stub_ish(fn conn ->
        :counters.add(counter, 1, 1)
        Req.Test.json(conn, IshFixtures.cluster_response(3))
      end)

      assert {:ok, _} = Ish.cluster(3, 1.5)
      assert {:ok, _} = Ish.cluster(3, 1.5)
      assert {:ok, _} = Ish.cluster(4, 2.0)
      assert :counters.get(counter, 1) == 2
    end
  end

  describe "date params" do
    test "data/2 forwards from/to as ISO query params" do
      stub_ish(fn conn ->
        assert conn.query_string == "from=2026-01-01&to=2026-02-01"
        Req.Test.json(conn, IshFixtures.entries())
      end)

      assert {:ok, _} = Ish.data(~D[2026-01-01], ~D[2026-02-01])
    end

    test "data/0 omits the query string when bounds are nil" do
      stub_ish(fn conn ->
        assert conn.query_string == ""
        Req.Test.json(conn, IshFixtures.entries())
      end)

      assert {:ok, _} = Ish.data()
    end

    test "data/2 caches per (from, to)" do
      counter = :counters.new(1, [])

      stub_ish(fn conn ->
        :counters.add(counter, 1, 1)
        Req.Test.json(conn, IshFixtures.entries())
      end)

      assert {:ok, _} = Ish.data()
      assert {:ok, _} = Ish.data(~D[2026-01-01], nil)
      assert {:ok, _} = Ish.data(~D[2026-01-01], nil)
      assert :counters.get(counter, 1) == 2
    end

    test "cluster/4 caches per (k, m, from, to)" do
      counter = :counters.new(1, [])

      stub_ish(fn conn ->
        :counters.add(counter, 1, 1)
        Req.Test.json(conn, IshFixtures.cluster_response(3))
      end)

      assert {:ok, _} = Ish.cluster(3, 1.5)
      assert {:ok, _} = Ish.cluster(3, 1.5, ~D[2026-01-01], nil)
      assert {:ok, _} = Ish.cluster(3, 1.5, ~D[2026-01-01], nil)
      assert :counters.get(counter, 1) == 2
    end
  end

  describe "membership_functions/0" do
    test "returns parsed definitions" do
      stub_ish(fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/membership-functions"
        Req.Test.json(conn, IshFixtures.membership_defs())
      end)

      assert {:ok, %{"inputs" => inputs, "outputs" => []}} = Ish.membership_functions()
      assert length(inputs) == 5
    end
  end

  describe "update_membership_functions/1" do
    test "posts JSON body and returns the committed defs" do
      defs = IshFixtures.membership_defs()

      stub_ish(fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/membership-functions"
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == defs
        Req.Test.json(conn, defs)
      end)

      assert {:ok, ^defs} = Ish.update_membership_functions(defs)
    end

    test "invalidates the IshCache on success" do
      # Pre-populate the cache.
      IshCache.fetch(:data, fn -> {:ok, "stale"} end)
      assert IshCache.fetch(:data, fn -> flunk("cache miss") end) == {:ok, "stale"}

      stub_ish(fn conn -> Req.Test.json(conn, IshFixtures.membership_defs()) end)
      assert {:ok, _} = Ish.update_membership_functions(IshFixtures.membership_defs())

      # After invalidation, the next fetch must run again.
      assert IshCache.fetch(:data, fn -> {:ok, "fresh"} end) == {:ok, "fresh"}
    end

    test "does not invalidate the cache on failure" do
      IshCache.fetch(:data, fn -> {:ok, "stale"} end)

      stub_ish(fn conn -> Plug.Conn.send_resp(conn, 500, "nope") end)
      assert {:error, _} = Ish.update_membership_functions(%{})

      # Still cached.
      assert IshCache.fetch(:data, fn -> flunk("cache should still hold") end) == {:ok, "stale"}
    end
  end

  describe "suggest_membership_functions/0" do
    test "returns the suggestion body" do
      stub_ish(fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/membership-functions/suggest"
        Req.Test.json(conn, IshFixtures.suggested_membership_defs())
      end)

      assert {:ok, %{"inputs" => inputs}} = Ish.suggest_membership_functions()
      assert length(inputs) == 5
    end
  end

  # -- helpers --

  defp stub_ish(fun) do
    Req.Test.stub(Fugue.Ish, fun)
  end
end
