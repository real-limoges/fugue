defmodule Fugue.DbTest do
  use ExUnit.Case, async: false

  alias Fugue.Db

  @url "http://cozo.test"
  @ping_body %{"script" => "?[] <- [[1]]", "params" => %{}}

  setup do
    Req.Test.set_req_test_to_shared()
    :ok
  end

  describe "start_link/1" do
    test "survives init when cozo answers the ping with ok:true" do
      stub(fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/text-query"
        Req.Test.json(conn, %{"ok" => true})
      end)

      {:ok, pid} = start_db()
      assert Process.alive?(pid)
      stop_db(pid)
    end

    test "fails init when cozo returns a non-200 status" do
      Process.flag(:trap_exit, true)
      stub(fn conn -> Plug.Conn.send_resp(conn, 500, "boom") end)

      Logger.configure(level: :emergency)

      assert {:error, _reason} = start_db()
    after
      Logger.configure(level: :warning)
    end
  end

  describe "query/2" do
    setup do
      stub_ping()
      {:ok, pid} = start_db()
      on_exit(fn -> stop_db(pid) end)
      :ok
    end

    test "returns rows zipped with headers on a successful query" do
      Req.Test.stub(Fugue.Db, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body = Jason.decode!(body)

        cond do
          body == @ping_body ->
            Req.Test.json(conn, %{"ok" => true})

          body["script"] == "?[id, title] := *articles[id, title]" ->
            Req.Test.json(conn, %{
              "ok" => true,
              "headers" => ["id", "title"],
              "rows" => [[1, "Alpha"], [2, "Beta"]]
            })

          true ->
            Plug.Conn.send_resp(conn, 404, "not stubbed")
        end
      end)

      assert {:ok, rows} = Db.query("?[id, title] := *articles[id, title]")

      assert rows == [
               %{"id" => 1, "title" => "Alpha"},
               %{"id" => 2, "title" => "Beta"}
             ]
    end

    test "maps Cozo ok:false with display string to an error tuple" do
      Req.Test.stub(Fugue.Db, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        if Jason.decode!(body) == @ping_body do
          Req.Test.json(conn, %{"ok" => true})
        else
          Req.Test.json(conn, %{"ok" => false, "display" => "syntax error near `?`"})
        end
      end)

      assert {:error, "syntax error near `?`"} = Db.query("not a real query")
    end

    test "maps Cozo ok:false with message field to an error tuple" do
      Req.Test.stub(Fugue.Db, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        if Jason.decode!(body) == @ping_body do
          Req.Test.json(conn, %{"ok" => true})
        else
          Req.Test.json(conn, %{"ok" => false, "message" => "no such relation"})
        end
      end)

      assert {:error, "no such relation"} = Db.query("?[x] := *missing[x]")
    end

    test "non-200 HTTP responses are wrapped in a readable error" do
      Req.Test.stub(Fugue.Db, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        if Jason.decode!(body) == @ping_body do
          Req.Test.json(conn, %{"ok" => true})
        else
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(502, ~s({"reason":"upstream"}))
        end
      end)

      assert {:error, "CozoDB HTTP 502: " <> _} = Db.query("?[x] := *things[x]")
    end

    test "query returns empty list when Cozo reports no rows" do
      Req.Test.stub(Fugue.Db, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        if Jason.decode!(body) == @ping_body do
          Req.Test.json(conn, %{"ok" => true})
        else
          Req.Test.json(conn, %{"ok" => true, "headers" => ["id"], "rows" => []})
        end
      end)

      assert {:ok, []} = Db.query("?[id] := *articles[id]")
    end
  end

  defp start_db(extra \\ []) do
    opts =
      [url: @url, plug: {Req.Test, Fugue.Db}]
      |> Keyword.merge(extra)

    Db.start_link(opts)
  end

  defp stop_db(pid) when is_pid(pid) do
    if Process.alive?(pid), do: GenServer.stop(pid)
  end

  defp stub(fun), do: Req.Test.stub(Fugue.Db, fun)

  defp stub_ping do
    Req.Test.stub(Fugue.Db, fn conn -> Req.Test.json(conn, %{"ok" => true}) end)
  end
end
