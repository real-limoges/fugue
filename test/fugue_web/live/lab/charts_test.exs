defmodule FugueWeb.LabLive.ChartsTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias FugueWeb.LabLive.Charts

  describe "linspace/3" do
    test "endpoints are inclusive" do
      xs = Charts.linspace(0.0, 1.0, 5)
      assert hd(xs) == 0.0
      assert List.last(xs) == 1.0
      assert length(xs) == 5
    end

    test "step is uniform" do
      [a, b, c | _] = Charts.linspace(2.0, 8.0, 7)
      assert_in_delta(b - a, c - b, 1.0e-9)
    end

    property "always produces n monotonically non-decreasing points" do
      check all(
              a <- StreamData.float(min: -100.0, max: 100.0),
              gap <- StreamData.float(min: 0.001, max: 100.0),
              n <- StreamData.integer(2..50)
            ) do
        b = a + gap
        xs = Charts.linspace(a, b, n)
        assert length(xs) == n
        assert hd(xs) == a
        # Floating-point reconstruction of b can drift by a single ULP.
        assert_in_delta(List.last(xs), b, 1.0e-10 + abs(b) * 1.0e-12)
        assert xs == Enum.sort(xs)
      end
    end
  end

  describe "gamma_density/3" do
    test "integrates to ~1 over a wide grid" do
      xs = Charts.linspace(0.001, 30.0, 600)
      pdf = Charts.gamma_density(xs, 3.0, 1.0)
      [x0, x1 | _] = xs
      area = Enum.sum(pdf) * (x1 - x0)
      assert_in_delta(area, 1.0, 0.01)
    end

    test "is non-negative everywhere" do
      xs = Charts.linspace(0.0, 20.0, 250)
      pdf = Charts.gamma_density(xs, 2.0, 0.4)
      assert Enum.all?(pdf, &(&1 >= 0.0))
    end

    test "evaluates to 0 at x <= 0" do
      xs = Charts.linspace(-1.0, 5.0, 100)
      pdf = Charts.gamma_density(xs, 2.0, 0.4)
      first = hd(pdf)
      assert first == 0.0
    end

    test "stays finite for large alpha (log-domain stability)" do
      xs = Charts.linspace(0.001, 200.0, 250)
      pdf = Charts.gamma_density(xs, 80.0, 1.0)
      assert Enum.all?(pdf, fn v -> is_float(v) and v >= 0.0 end)
      [x0, x1 | _] = xs
      area = Enum.sum(pdf) * (x1 - x0)
      assert_in_delta(area, 1.0, 0.05)
    end
  end

  describe "tail_probability/3" do
    test "tail at -infinity is the full mass" do
      xs = Charts.linspace(0.001, 30.0, 600)
      pdf = Charts.gamma_density(xs, 3.0, 1.0)
      assert_in_delta(Charts.tail_probability(xs, pdf, -1.0), 1.0, 0.01)
    end

    test "tail at +infinity is 0" do
      xs = Charts.linspace(0.001, 30.0, 600)
      pdf = Charts.gamma_density(xs, 3.0, 1.0)
      assert Charts.tail_probability(xs, pdf, 1000.0) == 0.0
    end

    test "monotonically decreases with threshold" do
      xs = Charts.linspace(0.001, 30.0, 400)
      pdf = Charts.gamma_density(xs, 4.0, 1.0)

      probs =
        for t <- [1.0, 2.0, 4.0, 8.0, 16.0] do
          Charts.tail_probability(xs, pdf, t)
        end

      assert probs == Enum.sort(probs, :desc)
    end

    test "result is clamped to [0, 1]" do
      xs = Charts.linspace(0.001, 5.0, 100)
      pdf = Charts.gamma_density(xs, 2.0, 1.0)

      for t <- [-100.0, 0.0, 1.0, 1000.0] do
        p = Charts.tail_probability(xs, pdf, t)
        assert p >= 0.0 and p <= 1.0
      end
    end
  end

  describe "polyline_path/4" do
    test "starts with a single move command and uses L thereafter" do
      sx = fn x -> x end
      sy = fn y -> y end
      d = Charts.polyline_path([0.0, 1.0, 2.0], [0.0, 1.0, 0.0], sx, sy)

      assert String.starts_with?(d, "M")
      assert d |> String.graphemes() |> Enum.count(&(&1 == "M")) == 1
      assert d =~ "L"
    end

    test "produces a coordinate per (x, y) pair" do
      sx = fn x -> x * 10 end
      sy = fn y -> y * 10 end
      d = Charts.polyline_path([0.0, 1.0, 2.0, 3.0], [0.0, 0.0, 0.0, 0.0], sx, sy)
      assert String.graphemes(d) |> Enum.count(&(&1 in ["M", "L"])) == 4
    end
  end

  describe "tail_polygon_path/5" do
    test "returns nil when no points fall in the tail" do
      sx = fn x -> x end
      sy = fn y -> y end
      assert Charts.tail_polygon_path([0.0, 1.0, 2.0], [1.0, 1.0, 1.0], 100.0, sx, sy) == nil
    end

    test "closed path starts and ends on the y=0 baseline" do
      sx = fn x -> x * 100 end
      sy = fn y -> 200.0 - y * 100 end
      d = Charts.tail_polygon_path([0.0, 1.0, 2.0, 3.0], [0.5, 0.6, 0.4, 0.2], 1.0, sx, sy)

      base_y = sy.(0)
      assert is_binary(d)
      assert String.ends_with?(d, "Z")
      assert d =~ ",#{:erlang.float_to_binary(base_y, decimals: 2)}"
    end
  end

  describe "axis_frame/1" do
    test "scale_x maps the domain endpoints onto the inner viewport" do
      f =
        Charts.axis_frame(
          width: 400,
          height: 200,
          x_range: {0.0, 10.0},
          y_range: {0.0, 1.0}
        )

      assert_in_delta(f.scale_x.(0.0), f.margin.left, 1.0e-9)
      assert_in_delta(f.scale_x.(10.0), f.margin.left + f.inner_w, 1.0e-9)
    end

    test "scale_y is inverted (top of viewport = max value)" do
      f =
        Charts.axis_frame(
          width: 400,
          height: 200,
          x_range: {0.0, 1.0},
          y_range: {0.0, 1.0}
        )

      assert f.scale_y.(0.0) > f.scale_y.(1.0)
    end

    test "tick lists are populated when supplied" do
      f =
        Charts.axis_frame(
          width: 400,
          height: 200,
          x_range: {0.0, 10.0},
          y_range: {0.0, 1.0},
          x_ticks: [0, 5, 10],
          y_ticks: [0.0, 0.5, 1.0]
        )

      assert Enum.map(f.x_ticks, & &1.value) == [0, 5, 10]
      assert Enum.map(f.y_ticks, & &1.value) == [0.0, 0.5, 1.0]
    end
  end

  describe "format_tick/1" do
    test "integers stringify directly" do
      assert Charts.format_tick(0) == "0"
      assert Charts.format_tick(42) == "42"
    end

    test "whole-valued floats drop the decimal" do
      assert Charts.format_tick(3.0) == "3"
    end

    test "non-integer floats trim trailing zeros" do
      assert Charts.format_tick(0.5) == "0.5"
      assert Charts.format_tick(1.25) == "1.25"
    end
  end
end
