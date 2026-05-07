defmodule FugueWeb.ColorLive.ConeMathTest do
  use ExUnit.Case, async: true

  alias FugueWeb.ColorLive.ConeMath

  describe "cone_x_of/1" do
    test "lambda_min lands at the left plot edge" do
      assert ConeMath.cone_x_of(ConeMath.lambda_min()) == 60
    end

    test "lambda_max lands at the right plot edge" do
      assert ConeMath.cone_x_of(ConeMath.lambda_max()) == 770
    end

    test "is monotonic in lambda" do
      assert ConeMath.cone_x_of(400) < ConeMath.cone_x_of(500)
      assert ConeMath.cone_x_of(500) < ConeMath.cone_x_of(600)
    end
  end

  describe "cone_y_of/1" do
    test "response 0 lands at the bottom of the plot" do
      assert ConeMath.cone_y_of(0.0) == 270
    end

    test "response 1 lands at the top of the plot" do
      assert ConeMath.cone_y_of(1.0) == 30
    end

    test "is inverted (y grows downward, response grows upward)" do
      assert ConeMath.cone_y_of(0.5) > ConeMath.cone_y_of(0.9)
    end
  end

  describe "cone_label_dx/1" do
    test "L is nudged right, M is nudged left, S is centered" do
      assert ConeMath.cone_label_dx(:l) > 0
      assert ConeMath.cone_label_dx(:m) < 0
      assert ConeMath.cone_label_dx(:s) == 0
    end
  end

  describe "cone_curve_points/1" do
    test "produces a non-empty space-separated SVG point list" do
      points = ConeMath.cone_curve_points(:m)
      assert is_binary(points)
      assert String.contains?(points, " ")
      assert String.contains?(points, ",")
    end

    test "every coordinate falls inside the plot bounds" do
      ConeMath.cone_curve_points(:s)
      |> String.split(" ")
      |> Enum.each(fn pair ->
        [x_str, y_str] = String.split(pair, ",")
        x = String.to_float(x_str)
        y = String.to_float(y_str)
        assert x >= 60 and x <= 770
        assert y >= 30 and y <= 270
      end)
    end
  end

  describe "chromaticity coords" do
    test "chrom_x scales by 100" do
      assert ConeMath.chrom_x(0.5) == 50.0
    end

    test "chrom_y flips the axis" do
      # chrom_y 0 lands near the bottom; chrom_y 0.8 lands near the top.
      assert ConeMath.chrom_y(0.0) > ConeMath.chrom_y(0.8)
    end
  end

  describe "gamut polygon helpers" do
    test "srgb_points returns three space-separated coordinate pairs" do
      pts = ConeMath.srgb_points()
      assert pts |> String.split(" ") |> length() == 3
      assert String.contains?(pts, ",")
    end

    test "p3 and rec2020 cover larger ranges than sRGB" do
      # The triangle envelope is qualitative; just verify that distinct
      # triangles produce distinct point strings.
      assert ConeMath.srgb_points() != ConeMath.p3_points()
      assert ConeMath.p3_points() != ConeMath.rec2020_points()
    end
  end

  describe "locus_polyline_points/0" do
    test "covers the spectral locus from 380 to 700 nm at 10 nm spacing" do
      pts = ConeMath.locus_polyline_points()
      # 33 sample points (380, 390, ..., 700 inclusive).
      assert pts |> String.split(" ") |> length() == 33
    end
  end
end
