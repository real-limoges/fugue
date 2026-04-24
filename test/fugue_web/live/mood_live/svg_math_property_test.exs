defmodule FugueWeb.MoodLive.SvgMathPropertyTest do
  @moduledoc """
  Property-based tests for the shared path/number helpers in `SvgMath`.

  These pin down contract-level invariants of `basis_path/1` that example
  tests miss: path well-formedness across random point sets, round-trip
  precision of `fmt/1`, and geometric properties (collinear inputs, endpoint
  preservation) that the d3-equivalent curveBasis also satisfies.
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias FugueWeb.MoodLive.SvgMath

  # --- generators ----------------------------------------------------------

  # Finite floats bounded to a safe range for geometry. StreamData's `float/0`
  # includes +/-Infinity and NaN by default, which we never see in real data.
  defp finite_float(min \\ -10_000.0, max \\ 10_000.0) do
    StreamData.float(min: min, max: max)
  end

  defp point, do: StreamData.tuple({finite_float(), finite_float()})

  defp points(min_length) do
    StreamData.list_of(point(), min_length: min_length, max_length: 20)
  end

  # --- fmt/1 --------------------------------------------------------------

  describe "fmt/1 property" do
    property "integers always render as the integer's decimal representation" do
      check all(n <- StreamData.integer()) do
        assert SvgMath.fmt(n) == Integer.to_string(n)
      end
    end

    property "floats round-trip within 0.01 of the input" do
      check all(f <- finite_float()) do
        out = SvgMath.fmt(f)
        {parsed, _} = Float.parse(out)
        assert_in_delta(parsed, f, 0.01)
      end
    end

    property "float output never contains NaN/Infinity markers" do
      check all(f <- finite_float()) do
        out = SvgMath.fmt(f)
        refute out =~ ~r/inf|nan/i
      end
    end

    property "float output uses at most 2 decimal places" do
      check all(f <- finite_float()) do
        out = SvgMath.fmt(f)

        case String.split(out, ".") do
          [_int] -> :ok
          [_int, frac] -> assert byte_size(frac) <= 2
        end
      end
    end
  end

  # --- basis_path/1 -------------------------------------------------------

  describe "basis_path/1 property" do
    property "empty input yields an empty string" do
      # Degenerate sanity check — single generated value to exercise
      # ExUnitProperties runner even when the input is fixed.
      check all(_ <- StreamData.constant(nil)) do
        assert SvgMath.basis_path([]) == ""
      end
    end

    property "any non-empty input produces a path that starts with `M`" do
      check all(pts <- points(1)) do
        path = SvgMath.basis_path(pts)
        assert String.starts_with?(path, "M")
      end
    end

    property "the generated path is never empty for non-empty input" do
      check all(pts <- points(1)) do
        path = SvgMath.basis_path(pts)
        assert byte_size(path) > 0
      end
    end

    property "the final coordinate on the path matches the final input point" do
      check all(pts <- points(2)) do
        {last_x, last_y} = List.last(pts)
        path = SvgMath.basis_path(pts)
        assert String.ends_with?(path, "L#{SvgMath.fmt(last_x)},#{SvgMath.fmt(last_y)}")
      end
    end

    property "the path contains cubic beziers (`C`) iff input has 3+ points" do
      check all(pts <- points(0), pts != []) do
        path = SvgMath.basis_path(pts)

        case length(pts) do
          n when n < 3 -> refute path =~ "C"
          _ -> assert path =~ "C"
        end
      end
    end

    property "path output is free of NaN/Infinity markers" do
      check all(pts <- points(1)) do
        path = SvgMath.basis_path(pts)
        refute path =~ ~r/inf|nan/i
      end
    end

    property "points collinear on y = y0 produce a path whose y-coords are all y0 (to 2dp)" do
      check all(
              y0 <- finite_float(-100.0, 100.0),
              xs <-
                StreamData.list_of(finite_float(-1000.0, 1000.0), min_length: 2, max_length: 15)
            ) do
        pts = Enum.map(xs, &{&1, y0})
        path = SvgMath.basis_path(pts)
        assert all_y_equal?(path, SvgMath.fmt(y0))
      end
    end

    property "points collinear on x = x0 produce a path whose x-coords are all x0 (to 2dp)" do
      check all(
              x0 <- finite_float(-100.0, 100.0),
              ys <-
                StreamData.list_of(finite_float(-1000.0, 1000.0), min_length: 2, max_length: 15)
            ) do
        pts = Enum.map(ys, &{x0, &1})
        path = SvgMath.basis_path(pts)
        assert all_x_equal?(path, SvgMath.fmt(x0))
      end
    end

    property "the bezier count grows linearly with input size" do
      # For N >= 3 points, d3.curveBasis emits N-1 bezier segments total:
      # (N-2) main beziers through interior trios + 1 final degenerate bezier.
      check all(pts <- points(3)) do
        path = SvgMath.basis_path(pts)
        bezier_count = path |> String.split("C") |> length() |> Kernel.-(1)
        assert bezier_count == length(pts) - 1
      end
    end

    property "path command structure: every command letter is M, L, C, or Z" do
      check all(pts <- points(1)) do
        path = SvgMath.basis_path(pts)

        # Extract non-numeric, non-separator characters.
        # Valid tokens in our output: M, L, C, comma, space, digits, ., -.
        stray = String.replace(path, ~r/[MLCZ0-9.,\s\-]/, "")
        assert stray == ""
      end
    end

    property "duplicating the first point doesn't change endpoint or break the path" do
      check all(pts <- points(2)) do
        path_original = SvgMath.basis_path(pts)
        {x0, y0} = List.first(pts)

        # Path with a leading duplicate.
        path_dup = SvgMath.basis_path([{x0, y0} | pts])

        assert String.starts_with?(path_dup, "M")
        # Both paths should end at the same final point.
        {last_x, last_y} = List.last(pts)
        suffix = "L#{SvgMath.fmt(last_x)},#{SvgMath.fmt(last_y)}"
        assert String.ends_with?(path_original, suffix)
        assert String.ends_with?(path_dup, suffix)
      end
    end
  end

  # --- helpers -------------------------------------------------------------

  # Given an SVG path string like "M0,5L2.5,5C...5...L10,5", extract every
  # (x, y) pair from the M/L/C command arguments and assert their y components
  # all equal the expected string form. Bezier control points are included —
  # which is the correct invariant: a curve through collinear y=y0 points
  # must have every control point on y=y0 or the curve would bulge.
  defp all_y_equal?(path, expected_y_fmt) do
    pairs = extract_coord_pairs(path)
    Enum.all?(pairs, fn {_x_fmt, y_fmt} -> y_fmt == expected_y_fmt end)
  end

  defp all_x_equal?(path, expected_x_fmt) do
    pairs = extract_coord_pairs(path)
    Enum.all?(pairs, fn {x_fmt, _y_fmt} -> x_fmt == expected_x_fmt end)
  end

  # Split on any command letter, drop empty chunks, then parse each chunk as
  # a sequence of comma- or space-separated x,y pairs.
  defp extract_coord_pairs(path) do
    path
    |> String.split(~r/[MLCZ]/, trim: true)
    |> Enum.flat_map(&parse_pairs/1)
  end

  defp parse_pairs(chunk) do
    # Coordinates are separated by spaces between pairs and "," within pairs.
    # But the chunk "5.0,0.0" is one pair; "5.0,0.0 2.5,0.0 0.83,0.0" is three.
    chunk
    |> String.trim()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map(fn pair ->
      case String.split(pair, ",") do
        [x, y] -> {x, y}
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
end
