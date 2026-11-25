defmodule Fugue.Fuzzy.MembershipTest do
  use ExUnit.Case, async: true

  alias Fugue.Fuzzy.Membership

  describe "triangular/3" do
    setup do
      %{mf: Membership.triangular(0.0, 5.0, 10.0)}
    end

    test "zero outside the support", %{mf: mf} do
      assert mf.(-1.0) == 0.0
      assert mf.(10.0) == 0.0
      assert mf.(99.0) == 0.0
    end

    test "one at the peak", %{mf: mf} do
      assert mf.(5.0) == 1.0
    end

    test "linear ramps on either side", %{mf: mf} do
      assert mf.(2.5) == 0.5
      assert_in_delta mf.(7.5), 0.5, 1.0e-9
    end

    test "a shoulder is one at its peak" do
      left = Membership.triangular(0.0, 0.0, 26.0)
      right = Membership.triangular(18.0, 40.0, 40.0)

      assert left.(0.0) == 1.0
      assert left.(13.0) == 0.5
      assert right.(40.0) == 1.0
      assert right.(29.0) == 0.5
    end
  end
end
