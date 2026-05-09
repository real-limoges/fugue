defmodule FugueWeb.MoodLive.FocusTest do
  use ExUnit.Case, async: true

  alias FugueWeb.MoodLive.Focus
  alias FugueWeb.MoodLive.Structs.GapData

  describe "transitions: single-focus invariant" do
    test "select_day from :none focuses the day" do
      assert Focus.select_day(:none, "2024-01-01") == {:day, "2024-01-01"}
    end

    test "select_day from a cluster focus replaces it (no coexistence)" do
      assert Focus.select_day({:cluster, "calm"}, "2024-01-01") == {:day, "2024-01-01"}
    end

    test "select_day from a gap focus replaces it" do
      gap = %{"start" => "2024-01-01", "length" => 3}
      assert Focus.select_day({:gap, gap}, "2024-02-01") == {:day, "2024-02-01"}
    end

    test "select_cluster on a different cluster replaces it" do
      assert Focus.select_cluster({:cluster, "calm"}, "spike") == {:cluster, "spike"}
    end

    test "select_cluster on the same cluster toggles to :none" do
      assert Focus.select_cluster({:cluster, "calm"}, "calm") == :none
    end

    test "select_cluster from a day focus replaces it" do
      assert Focus.select_cluster({:day, "2024-01-01"}, "calm") == {:cluster, "calm"}
    end

    test "select_gap replaces any other focus" do
      gap = %{"start" => "2024-01-01", "length" => 3}
      assert Focus.select_gap({:cluster, "calm"}, gap) == {:gap, gap}
      assert Focus.select_gap({:day, "2024-02-02"}, gap) == {:gap, gap}
    end

    test "clear collapses any focus to :none" do
      assert Focus.clear({:day, "2024-01-01"}) == :none
      assert Focus.clear({:cluster, "calm"}) == :none
      assert Focus.clear({:gap, %{"start" => "x", "length" => 1}}) == :none
      assert Focus.clear(:none) == :none
    end

    test "selecting day then cluster then day yields only day -- no leak" do
      focus =
        :none
        |> Focus.select_cluster("calm")
        |> Focus.select_day("2024-01-01")

      assert focus == {:day, "2024-01-01"}
    end
  end

  describe "highlights/3" do
    @entries [
      %{"date" => "2024-01-01"},
      %{"date" => "2024-01-02"},
      %{"date" => "2024-01-03"},
      %{"date" => "2024-01-04"}
    ]

    test "day focus overrides brush, returns just that date" do
      assert Focus.highlights({:day, "2024-01-02"}, {"2024-01-01", "2024-01-04"}, @entries) ==
               ["2024-01-02"]
    end

    test "day focus with no brush returns just that date" do
      assert Focus.highlights({:day, "2024-01-02"}, nil, @entries) == ["2024-01-02"]
    end

    test "brush range without focus returns dates in range" do
      assert Focus.highlights(:none, {"2024-01-02", "2024-01-03"}, @entries) ==
               ["2024-01-02", "2024-01-03"]
    end

    test "cluster focus contributes no dates" do
      assert Focus.highlights({:cluster, "calm"}, nil, @entries) == []
    end

    test "gap focus contributes no dates" do
      gap = %{"start" => "2024-01-01", "length" => 3}
      assert Focus.highlights({:gap, gap}, nil, @entries) == []
    end

    test "cluster + brush returns brush dates (cluster doesn't fill)" do
      assert Focus.highlights({:cluster, "calm"}, {"2024-01-02", "2024-01-03"}, @entries) ==
               ["2024-01-02", "2024-01-03"]
    end

    test "no focus, no brush returns []" do
      assert Focus.highlights(:none, nil, @entries) == []
    end
  end

  describe "gap_transitions/2" do
    @gaps %GapData{
      transitions: [
        %{"before" => %{"calm" => 0.6, "spike" => 0.1}, "after" => %{"calm" => 0.2}},
        %{"before" => %{"calm" => 0.1}, "after" => %{"spike" => 0.5}},
        %{"before" => %{"spike" => 0.2}, "after" => %{"spike" => 0.4}}
      ],
      imputed_memberships: %{}
    }

    test "returns [] when gaps not loaded" do
      assert Focus.gap_transitions(nil, :none) == []
      assert Focus.gap_transitions(nil, {:cluster, "calm"}) == []
    end

    test "returns full list when no cluster focus" do
      assert Focus.gap_transitions(@gaps, :none) == @gaps.transitions
      assert Focus.gap_transitions(@gaps, {:day, "2024-01-01"}) == @gaps.transitions
    end

    test "filters to transitions where focused cluster has >= 0.3 before or after" do
      result = Focus.gap_transitions(@gaps, {:cluster, "calm"})
      assert length(result) == 1
      assert hd(result)["before"]["calm"] == 0.6
    end

    test "filters by spike cluster" do
      result = Focus.gap_transitions(@gaps, {:cluster, "spike"})
      assert length(result) == 2
    end

    test "missing cluster keys default to 0 (no match)" do
      result = Focus.gap_transitions(@gaps, {:cluster, "absent"})
      assert result == []
    end
  end
end
