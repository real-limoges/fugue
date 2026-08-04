defmodule Fugue.MembershipDefaultsTest do
  use ExUnit.Case, async: true

  alias Fugue.MembershipDefaults
  alias Fugue.Mood.Fuzzify

  test "get/0 returns the canonical default membership func defs" do
    assert {:ok, defs} = MembershipDefaults.get()
    assert defs == Fuzzify.default_membership_func_defs()
  end

  test "get/0 is consistent across calls (pure, no cached/mutated state)" do
    assert MembershipDefaults.get() == MembershipDefaults.get()
  end
end
