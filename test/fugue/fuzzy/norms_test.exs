defmodule Fugue.Fuzzy.NormsTest do
  use ExUnit.Case, async: true

  alias Fugue.Fuzzy.Norms

  describe "t_norm/3" do
    test ":min_max is min" do
      assert Norms.t_norm(:min_max, 0.3, 0.7) == 0.3
    end

    test ":product is a*b" do
      assert Norms.t_norm(:product, 0.5, 0.4) == 0.2
    end

    test ":lukasiewicz is max(0, a+b-1)" do
      assert Norms.t_norm(:lukasiewicz, 0.3, 0.4) == 0.0
      assert_in_delta Norms.t_norm(:lukasiewicz, 0.7, 0.8), 0.5, 1.0e-9
    end
  end

  describe "s_norm/3" do
    test ":min_max is max" do
      assert Norms.s_norm(:min_max, 0.3, 0.7) == 0.7
    end

    test ":product is a+b-a*b" do
      assert_in_delta Norms.s_norm(:product, 0.5, 0.4), 0.7, 1.0e-9
    end

    test ":lukasiewicz is min(1, a+b)" do
      assert Norms.s_norm(:lukasiewicz, 0.3, 0.4) == 0.7
      assert Norms.s_norm(:lukasiewicz, 0.7, 0.8) == 1.0
    end
  end
end
