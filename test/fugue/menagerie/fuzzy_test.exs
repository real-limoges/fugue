defmodule Fugue.Menagerie.FuzzyTest do
  use ExUnit.Case, async: true

  alias Fugue.Menagerie.Fuzzy

  describe "triangular/4" do
    test "zero outside the support" do
      assert Fuzzy.triangular(-1.0, 0.0, 5.0, 10.0) == 0.0
      assert Fuzzy.triangular(10.0, 0.0, 5.0, 10.0) == 0.0
      assert Fuzzy.triangular(99.0, 0.0, 5.0, 10.0) == 0.0
    end

    test "one at the peak" do
      assert Fuzzy.triangular(5.0, 0.0, 5.0, 10.0) == 1.0
    end

    test "linear ramp up on the left slope" do
      assert Fuzzy.triangular(2.5, 0.0, 5.0, 10.0) == 0.5
      assert Fuzzy.triangular(1.0, 0.0, 5.0, 10.0) == 0.2
    end

    test "linear ramp down on the right slope" do
      assert Fuzzy.triangular(7.5, 0.0, 5.0, 10.0) == 0.5
    end

    test "non-numeric input falls back to zero" do
      assert Fuzzy.triangular(nil, 0.0, 5.0, 10.0) == 0.0
    end
  end

  describe "build_mfs/2" do
    test "default params produce five bands with the documented names" do
      mfs = Fuzzy.build_mfs(0.0, 1.0)

      assert Enum.map(mfs, & &1.name) == ~w(cold cool mild warm hot)
      assert Enum.all?(mfs, &is_binary(&1.color))
    end

    test "default peaks match the base celsius values" do
      mfs = Fuzzy.build_mfs(0.0, 1.0)
      assert Enum.map(mfs, & &1.b) == [10.0, 17.0, 24.0, 31.0, 38.0]
    end

    test "center_offset shifts every peak by the same amount" do
      peaks_base = Fuzzy.build_mfs(0.0, 1.0) |> Enum.map(& &1.b)
      peaks_offset = Fuzzy.build_mfs(3.0, 1.0) |> Enum.map(& &1.b)

      assert Enum.zip(peaks_offset, peaks_base)
             |> Enum.all?(fn {o, b} -> o - b == 3.0 end)
    end

    test "spread scales the half-width so a and c move but b doesn't" do
      [cold_narrow | _] = Fuzzy.build_mfs(0.0, 0.5)
      [cold_wide | _] = Fuzzy.build_mfs(0.0, 2.0)

      assert cold_narrow.b == cold_wide.b
      assert cold_wide.c - cold_wide.b == 4 * (cold_narrow.c - cold_narrow.b)
    end
  end

  describe "default_mfs/0" do
    test "matches build_mfs(0.0, 1.0)" do
      assert Fuzzy.default_mfs() == Fuzzy.build_mfs(0.0, 1.0)
    end
  end

  describe "sample_shape/4" do
    test "returns steps + 1 points covering the bounds" do
      [mf | _] = Fuzzy.build_mfs(0.0, 1.0)
      samples = Fuzzy.sample_shape(mf, 0.0, 48.0, 80)

      assert length(samples) == 81
      assert [first_x, _] = List.first(samples)
      assert [last_x, _] = List.last(samples)
      assert first_x == 0.0
      assert last_x == 48.0
    end

    test "every sample is a two-element list with numeric y" do
      [mf | _] = Fuzzy.build_mfs(0.0, 1.0)
      samples = Fuzzy.sample_shape(mf, 0.0, 48.0, 20)

      assert Enum.all?(samples, fn [x, y] ->
               is_number(x) and is_number(y) and y >= 0.0 and y <= 1.0
             end)
    end

    test "hits 1.0 at the peak when the peak lies on a sample point" do
      mf = %{a: 0.0, b: 10.0, c: 20.0, name: "t", color: "#fff"}
      samples = Fuzzy.sample_shape(mf, 0.0, 20.0, 20)

      peak = Enum.find(samples, fn [x, _] -> x == 10.0 end)
      assert peak == [10.0, 1.0]
    end
  end

  describe "memberships/2" do
    test "normalizes so values sum to 1 when any triangle is active" do
      mfs = Fuzzy.build_mfs(0.0, 1.0)
      mems = Fuzzy.memberships(22.0, mfs)

      total = mems |> Map.values() |> Enum.sum()
      assert_in_delta total, 1.0, 1.0e-9
    end

    test "all zeros when the value sits outside every triangle" do
      mfs = Fuzzy.build_mfs(0.0, 1.0)
      mems = Fuzzy.memberships(-999.0, mfs)

      assert Map.values(mems) |> Enum.all?(&(&1 == 0.0))
    end

    test "returns one entry per mf, keyed by name" do
      mfs = Fuzzy.build_mfs(0.0, 1.0)
      mems = Fuzzy.memberships(22.0, mfs)

      assert Map.keys(mems) |> Enum.sort() == ~w(cold cool hot mild warm)
    end
  end

  describe "bands/2" do
    test "one entry per row, preserving order" do
      mfs = Fuzzy.build_mfs(0.0, 1.0)
      rows = [row("2026-01-01", 10.0), row("2026-01-02", 30.0)]

      result = Fuzzy.bands(rows, mfs)

      assert Enum.map(result, & &1.date) == ["2026-01-01", "2026-01-02"]
    end

    test "rows with nil tmax produce an all-zero row (rendered as a gap)" do
      mfs = Fuzzy.build_mfs(0.0, 1.0)
      result = Fuzzy.bands([row("2026-01-01", nil)], mfs)

      [%{memberships: mems}] = result
      assert Map.values(mems) |> Enum.all?(&(&1 == 0.0))
    end
  end

  defp row(date, tmax), do: %{date: date, tmax: tmax}
end
