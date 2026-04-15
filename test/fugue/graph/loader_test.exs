defmodule Fugue.Graph.LoaderTest do
  use ExUnit.Case, async: false

  alias Fugue.Graph.{Article, Link, Loader}

  @ping_body %{"script" => "?[] <- [[1]]", "params" => %{}}

  setup do
    Req.Test.set_req_test_to_shared()
    stub_ping()

    {:ok, pid} = Fugue.Db.start_link(url: "http://cozo.test", plug: {Req.Test, Fugue.Db})
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

    :ok
  end

  describe "search_articles/1" do
    test "returns the ids from the cozo result rows" do
      route(fn
        %{"needle" => "rust"}, _ ->
          %{
            "ok" => true,
            "headers" => ["id", "title"],
            "rows" => [[1, "Rust"], [2, "Rust (programming language)"]]
          }
      end)

      assert {:ok, [1, 2]} = Loader.search_articles("Rust")
    end

    test "downcases the query before sending it to cozo" do
      route(fn
        %{"needle" => needle}, _ ->
          assert needle == "functional"
          %{"ok" => true, "headers" => ["id", "title"], "rows" => []}
      end)

      assert {:ok, []} = Loader.search_articles("FUNCTIONAL")
    end

    test "propagates errors from Fugue.Db" do
      route(fn _, _ -> %{"ok" => false, "display" => "boom"} end)

      assert {:error, "boom"} = Loader.search_articles("anything")
    end
  end

  describe "lookup_by_title/1" do
    test "returns the id when cozo has exactly one match" do
      route(fn
        %{"title" => "Rust (programming language)"}, _ ->
          %{"ok" => true, "headers" => ["id"], "rows" => [[29_414_838]]}
      end)

      assert {:ok, 29_414_838} = Loader.lookup_by_title("Rust (programming language)")
    end

    test "returns :not_found when cozo returns zero rows" do
      route(fn _, _ -> %{"ok" => true, "headers" => ["id"], "rows" => []} end)

      assert {:error, :not_found} = Loader.lookup_by_title("no such thing")
    end
  end

  describe "get_article/1" do
    test "hydrates the row into an Article struct" do
      route(fn
        %{"id" => 42}, _ ->
          %{
            "ok" => true,
            "headers" => ["id", "title", "pagerank", "community", "degree"],
            "rows" => [[42, "Haskell", 0.0123, 7, 88]]
          }
      end)

      assert {:ok, %Article{} = a} = Loader.get_article(42)
      assert a.id == 42
      assert a.title == "Haskell"
      assert a.pagerank == 0.0123
      assert a.community == 7
      assert a.degree == 88
    end

    test "returns :not_found when cozo returns zero rows" do
      route(fn _, _ ->
        %{
          "ok" => true,
          "headers" => ["id", "title", "pagerank", "community", "degree"],
          "rows" => []
        }
      end)

      assert {:error, :not_found} = Loader.get_article(999)
    end
  end

  describe "load_subgraph/2" do
    test "chains bfs_expand → fetch_articles → fetch_links into a unified map" do
      # seed_id = 1 with out-edges to 2 and 3; all three nodes exist in `article`;
      # `links_to` restricted to the id set returns only the edges we seeded.
      route(fn body, script ->
        cond do
          bfs_script?(script) ->
            assert body["seed_id"] == 1

            %{"ok" => true, "headers" => ["node"], "rows" => [[1], [2], [3]]}

          fetch_articles_script?(script) ->
            assert body["ids"] == [[1], [2], [3]]

            %{
              "ok" => true,
              "headers" => ["id", "title", "pagerank", "community", "degree"],
              "rows" => [
                [1, "Seed", 0.5, 0, 2],
                [2, "Neighbor A", 0.2, 0, 1],
                [3, "Neighbor B", 0.15, 1, 1]
              ]
            }

          fetch_links_script?(script) ->
            assert body["ids"] == [[1], [2], [3]]

            %{
              "ok" => true,
              "headers" => ["from_id", "to_id"],
              "rows" => [[1, 2], [1, 3]]
            }
        end
      end)

      assert {:ok, %{nodes: nodes, links: links}} = Loader.load_subgraph(1)

      assert Enum.map(nodes, & &1.id) == [1, 2, 3]
      assert Enum.all?(nodes, &match?(%Article{}, &1))

      assert links == [
               %Link{source_id: 1, target_id: 2},
               %Link{source_id: 1, target_id: 3}
             ]
    end

    test "surfaces errors from any of the three queries" do
      route(fn _body, script ->
        if bfs_script?(script) do
          %{"ok" => false, "display" => "cozo sad"}
        else
          flunk("should not reach subsequent queries after bfs error")
        end
      end)

      assert {:error, "cozo sad"} = Loader.load_subgraph(1)
    end

    test "short-circuits article/link lookups when bfs returns no ids" do
      route(fn _body, script ->
        if bfs_script?(script) do
          %{"ok" => true, "headers" => ["node"], "rows" => []}
        else
          flunk("should not query article/links_to for empty id set")
        end
      end)

      assert {:ok, %{nodes: [], links: []}} = Loader.load_subgraph(999)
    end
  end

  # -- routing helpers --

  defp route(handler) do
    Req.Test.stub(Fugue.Db, fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(raw)

      cond do
        decoded == @ping_body ->
          Req.Test.json(conn, %{"ok" => true})

        true ->
          payload = handler.(decoded["params"], decoded["script"])
          Req.Test.json(conn, payload)
      end
    end)
  end

  defp stub_ping do
    Req.Test.stub(Fugue.Db, fn conn -> Req.Test.json(conn, %{"ok" => true}) end)
  end

  defp bfs_script?(script), do: String.contains?(script, "$seed_id")

  defp fetch_articles_script?(script) do
    String.contains?(script, "ids[id]") and
      String.contains?(script, "*article{id, title, pagerank")
  end

  defp fetch_links_script?(script) do
    String.contains?(script, "*links_to{from_id, to_id}")
  end
end
