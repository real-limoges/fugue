defmodule Fugue.MembershipDefaultsTest do
  use ExUnit.Case, async: false

  alias Fugue.{IshFixtures, MembershipDefaults}

  @key {MembershipDefaults, :snapshot}

  setup do
    :persistent_term.erase(@key)

    on_exit(fn ->
      :persistent_term.erase(@key)
    end)

    :ok
  end

  describe "get/0" do
    test "fetches from Ish on first call and stores the snapshot" do
      defs = IshFixtures.membership_defs()
      Req.Test.stub(Fugue.Ish, fn conn -> Req.Test.json(conn, defs) end)

      assert {:ok, ^defs} = MembershipDefaults.get()
      assert :persistent_term.get(@key) == defs
    end

    test "subsequent calls do not re-hit Ish" do
      defs = IshFixtures.membership_defs()
      counter = :counters.new(1, [])

      Req.Test.stub(Fugue.Ish, fn conn ->
        :counters.add(counter, 1, 1)
        Req.Test.json(conn, defs)
      end)

      assert {:ok, _} = MembershipDefaults.get()
      assert {:ok, _} = MembershipDefaults.get()
      assert {:ok, _} = MembershipDefaults.get()

      assert :counters.get(counter, 1) == 1
    end

    test "returns the first snapshot even if Ish state mutates" do
      first = IshFixtures.membership_defs()
      second = IshFixtures.suggested_membership_defs()
      current = :atomics.new(1, [])
      :atomics.put(current, 1, 0)

      Req.Test.stub(Fugue.Ish, fn conn ->
        case :atomics.get(current, 1) do
          0 -> Req.Test.json(conn, first)
          _ -> Req.Test.json(conn, second)
        end
      end)

      assert {:ok, ^first} = MembershipDefaults.get()
      :atomics.put(current, 1, 1)
      assert {:ok, ^first} = MembershipDefaults.get()
    end

    test "does not populate persistent_term on fetch error" do
      Req.Test.stub(Fugue.Ish, fn conn -> Plug.Conn.send_resp(conn, 500, "boom") end)

      assert {:error, _} = MembershipDefaults.get()
      assert :persistent_term.get(@key, :miss) == :miss
    end

    test "retries the fetch on the next call after a prior failure" do
      counter = :counters.new(1, [])

      Req.Test.stub(Fugue.Ish, fn conn ->
        case :counters.get(counter, 1) do
          0 ->
            :counters.add(counter, 1, 1)
            Plug.Conn.send_resp(conn, 500, "boom")

          _ ->
            :counters.add(counter, 1, 1)
            Req.Test.json(conn, IshFixtures.membership_defs())
        end
      end)

      assert {:error, _} = MembershipDefaults.get()
      assert {:ok, _} = MembershipDefaults.get()
    end
  end
end
