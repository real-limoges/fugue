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
  end

  describe "trapezoidal/4" do
    setup do
      %{mf: Membership.trapezoidal(0.0, 2.0, 8.0, 10.0)}
    end

    test "zero outside the support", %{mf: mf} do
      assert mf.(-1.0) == 0.0
      assert mf.(10.0) == 0.0
    end

    test "one across the plateau", %{mf: mf} do
      assert mf.(2.0) == 1.0
      assert mf.(5.0) == 1.0
      assert mf.(8.0) == 1.0
    end

    test "linear ramps outside the plateau", %{mf: mf} do
      assert mf.(1.0) == 0.5
      assert_in_delta mf.(9.0), 0.5, 1.0e-9
    end
  end

  describe "gaussian/2" do
    test "one at the mean, symmetric decay" do
      mf = Membership.gaussian(0.0, 1.0)
      assert mf.(0.0) == 1.0
      assert_in_delta mf.(1.0), mf.(-1.0), 1.0e-9
      assert mf.(1.0) < mf.(0.0)
    end
  end

  describe "sigmoid/2" do
    test "half at the center, approaches 0/1 at the extremes" do
      mf = Membership.sigmoid(0.0, 1.0)
      assert_in_delta mf.(0.0), 0.5, 1.0e-9
      assert mf.(-50.0) < 0.001
      assert mf.(50.0) > 0.999
    end
  end
end
