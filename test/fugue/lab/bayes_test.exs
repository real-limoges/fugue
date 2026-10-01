defmodule Fugue.Lab.BayesTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Fugue.Lab.Bayes

  describe "search_prior/4" do
    property "is a probability distribution over every cell" do
      check all(
              rows <- integer(1..8),
              cols <- integer(1..8),
              peak_row <- integer(0..(rows - 1)),
              peak_col <- integer(0..(cols - 1)),
              sigma <- float(min: 0.5, max: 5.0)
            ) do
        grid = Bayes.search_prior(rows, cols, {peak_row, peak_col}, sigma)

        assert length(grid) == rows * cols
        assert Enum.all?(grid, &(&1 > 0))
        assert_in_delta Enum.sum(grid), 1.0, 1.0e-9
      end
    end

    test "is most likely at the peak" do
      grid = Bayes.search_prior(5, 5, {1, 1}, 1.4)
      peak = 1 * 5 + 1
      assert Enum.at(grid, peak) == Enum.max(grid)
    end
  end

  describe "search_miss/2" do
    property "zeroes the searched cell and keeps the rest a distribution" do
      check all(
              rows <- integer(2..6),
              cols <- integer(2..6),
              i <- integer(0..(rows * cols - 1))
            ) do
        prior = Bayes.search_prior(rows, cols, {0, 0}, 1.4)
        posterior = Bayes.search_miss(prior, i)

        assert Enum.at(posterior, i) == 0.0
        assert_in_delta Enum.sum(posterior), 1.0, 1.0e-9
      end
    end

    test "keeps the other cells in proportion" do
      assert Bayes.search_miss([0.5, 0.25, 0.25], 0) == [0.0, 0.5, 0.5]
    end

    test "leaves a grid with no mass left as all zeros" do
      assert Bayes.search_miss([0.0, 1.0], 1) == [0.0, 0.0]
    end
  end

  describe "rate_posterior/3" do
    test "adds the event count to alpha and the years to beta" do
      assert Bayes.rate_posterior({2.0, 0.4}, 9, 2) == {11.0, 2.4}
    end

    test "with nothing observed, is the prior" do
      assert Bayes.rate_posterior({2.0, 0.4}, 0, 0) == {2.0, 0.4}
    end
  end

  describe "poisson_sample/1" do
    test "is a non-negative integer" do
      for _ <- 1..200 do
        k = Bayes.poisson_sample(4.2)
        assert is_integer(k) and k >= 0
      end
    end

    test "averages close to the mean over many draws" do
      :rand.seed(:exsss, {1, 2, 3})
      draws = for _ <- 1..5_000, do: Bayes.poisson_sample(4.2)
      assert_in_delta Enum.sum(draws) / length(draws), 4.2, 0.15
    end
  end
end
