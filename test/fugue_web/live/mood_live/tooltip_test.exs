defmodule FugueWeb.MoodLive.TooltipTest do
  use ExUnit.Case, async: true

  alias FugueWeb.MoodLive.Tooltip

  test "an annotation's label and note are escaped" do
    html =
      Tooltip.annotation(
        %{label: "<b>loud</b>", date: "2024-01-02", note: "a & b"},
        "steady",
        "var(--mood-cluster-0)"
      )

    assert html =~ "&lt;b&gt;loud&lt;/b&gt;"
    assert html =~ "a &amp; b"
    refute html =~ "<b>"
  end

  test "an annotation without a cluster leaves the cluster line out" do
    html = Tooltip.annotation(%{label: "x", date: "2024-01-02", note: nil}, :none, "")

    refute html =~ "color:"
  end

  test "a cluster line shows its detail only when there is one" do
    assert Tooltip.cluster_line("2024-01-02", "3 days", "red", "steady") =~ "· 3 days"
    refute Tooltip.cluster_line("2024-01-02", :none, "red", "steady") =~ "·"
  end
end
