defmodule FugueWeb.MoodLive.SvgMathTest do
  use ExUnit.Case, async: true

  alias FugueWeb.MoodLive.SvgMath

  describe "fmt/1" do
    test "integers render without a decimal" do
      assert SvgMath.fmt(0) == "0"
      assert SvgMath.fmt(-5) == "-5"
      assert SvgMath.fmt(120) == "120"
    end

    test "floats render compactly with two decimal places of precision" do
      assert SvgMath.fmt(0.0) == "0.0"
      assert SvgMath.fmt(1.2345) == "1.23"
      assert SvgMath.fmt(-1.23456) == "-1.23"
    end
  end

  describe "basis_path/1" do
    test "empty input is empty path" do
      assert SvgMath.basis_path([]) == ""
    end

    test "single point is a moveTo" do
      assert SvgMath.basis_path([{10, 20}]) == "M10,20"
    end

    test "two points draw a straight line" do
      assert SvgMath.basis_path([{0, 0}, {10, 10}]) == "M0,0L10,10"
    end

    test "three+ points begin with M + L to the 5:1 midpoint toward P0" do
      # First segment of d3.curveBasis: lineTo((5*P0 + P1) / 6, ...).
      # With P0 = (0,0) and P1 = (6,0), that's (1.0, 0.0).
      path = SvgMath.basis_path([{0, 0}, {6, 0}, {12, 0}, {18, 0}])
      assert String.starts_with?(path, "M0,0L1.0,0.0")
    end

    test "curve is emitted as cubic beziers for four or more points" do
      path = SvgMath.basis_path([{0, 0}, {10, 10}, {20, 0}, {30, 10}])
      assert path =~ ~r/C[\d.,\s-]+/
    end

    test "curve ends with a final lineTo to the last point" do
      path = SvgMath.basis_path([{0, 0}, {10, 0}, {20, 0}, {30, 0}])
      assert String.ends_with?(path, "L30,0")
    end

    test "curve through collinear horizontal points stays on y=0" do
      path = SvgMath.basis_path([{0, 0.0}, {10, 0.0}, {20, 0.0}, {30, 0.0}])

      # Every coordinate pair in the path should end with ",0.0"
      # (either from "L", "C", or an inner ", " separator).
      assert path =~ ~r/,\s*0\.0/
      refute path =~ ~r/,\s*-?\d*\.\d*[1-9]/
    end
  end
end
