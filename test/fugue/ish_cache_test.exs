defmodule Fugue.IshCacheTest do
  use ExUnit.Case, async: false

  alias Fugue.IshCache

  setup do
    IshCache.invalidate_all()
    :ok
  end

  describe "fetch/2" do
    test "runs the fetcher on a miss and caches the result" do
      counter = :counters.new(1, [])

      value =
        IshCache.fetch(:k1, fn ->
          :counters.add(counter, 1, 1)
          {:ok, "computed"}
        end)

      assert value == {:ok, "computed"}
      assert :counters.get(counter, 1) == 1
    end

    test "returns the cached value on subsequent calls without re-running the fetcher" do
      counter = :counters.new(1, [])

      fetcher = fn ->
        :counters.add(counter, 1, 1)
        {:ok, "once"}
      end

      assert IshCache.fetch(:k2, fetcher) == {:ok, "once"}
      assert IshCache.fetch(:k2, fetcher) == {:ok, "once"}
      assert IshCache.fetch(:k2, fetcher) == {:ok, "once"}
      assert :counters.get(counter, 1) == 1
    end

    test "isolates different keys" do
      assert IshCache.fetch(:a, fn -> {:ok, 1} end) == {:ok, 1}
      assert IshCache.fetch(:b, fn -> {:ok, 2} end) == {:ok, 2}
      assert IshCache.fetch(:a, fn -> {:ok, "should not run"} end) == {:ok, 1}
    end

    test "supports compound keys like {:cluster, k, m}" do
      assert IshCache.fetch({:cluster, 3, 1.5}, fn -> {:ok, :x} end) == {:ok, :x}
      assert IshCache.fetch({:cluster, 4, 1.5}, fn -> {:ok, :y} end) == {:ok, :y}
      assert IshCache.fetch({:cluster, 3, 1.5}, fn -> flunk("should not run") end) == {:ok, :x}
    end
  end

  describe "invalidate_all/0" do
    test "clears every cached key" do
      IshCache.fetch(:a, fn -> {:ok, 1} end)
      IshCache.fetch(:b, fn -> {:ok, 2} end)
      IshCache.fetch({:cluster, 3, 1.5}, fn -> {:ok, 3} end)

      assert IshCache.invalidate_all() == :ok

      counter = :counters.new(1, [])

      fetcher = fn ->
        :counters.add(counter, 1, 1)
        {:ok, :fresh}
      end

      IshCache.fetch(:a, fetcher)
      IshCache.fetch(:b, fetcher)
      IshCache.fetch({:cluster, 3, 1.5}, fetcher)

      assert :counters.get(counter, 1) == 3
    end
  end
end
