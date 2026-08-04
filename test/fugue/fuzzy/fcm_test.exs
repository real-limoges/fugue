defmodule Fugue.Fuzzy.FCMTest do
  use ExUnit.Case, async: true

  alias Fugue.Fuzzy.FCM

  describe "init_membership/2" do
    test "each point's membership row sums to 1 and is deterministic" do
      rows = FCM.init_membership(4, 3)
      assert length(rows) == 4
      assert Enum.all?(rows, fn row -> length(row) == 3 end)

      for row <- rows do
        assert_in_delta Enum.sum(row), 1.0, 1.0e-9
      end

      assert FCM.init_membership(4, 3) == rows
    end
  end

  describe "distance/2" do
    test "euclidean distance" do
      assert FCM.distance([0.0, 0.0], [3.0, 4.0]) == 5.0
    end
  end

  describe "converged?/3" do
    test "true when the max cell-wise difference is below epsilon" do
      old = [[0.5, 0.5], [0.3, 0.7]]
      close = [[0.500001, 0.499999], [0.3, 0.7]]
      far = [[0.9, 0.1], [0.3, 0.7]]

      assert FCM.converged?(1.0e-3, old, close)
      refute FCM.converged?(1.0e-3, old, far)
    end
  end

  describe "run/2" do
    test "separates two well-separated point clouds into two clusters" do
      near_origin = [[0.0, 0.0], [0.0, 1.0], [1.0, 0.0], [1.0, 1.0]]
      near_ten = [[10.0, 10.0], [10.0, 11.0], [11.0, 10.0], [11.0, 11.0]]
      xs = near_origin ++ near_ten

      config = FCM.default_config(2)
      result = FCM.run(config, xs)

      assert length(result.centers) == 2
      assert result.iterations > 0

      # Each point's dominant (argmax-membership) cluster should agree with
      # its nearest center by plain distance -- i.e. the two point clouds
      # land in different clusters, not mixed together.
      dominant_clusters =
        Enum.map(result.membership, fn row ->
          row |> Enum.with_index() |> Enum.max_by(fn {m, _idx} -> m end) |> elem(1)
        end)

      {origin_clusters, ten_clusters} = Enum.split(dominant_clusters, 4)
      [origin_cluster] = Enum.uniq(origin_clusters)
      [ten_cluster] = Enum.uniq(ten_clusters)
      assert origin_cluster != ten_cluster
    end
  end
end
