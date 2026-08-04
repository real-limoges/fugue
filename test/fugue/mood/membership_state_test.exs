defmodule Fugue.Mood.MembershipStateTest do
  use ExUnit.Case, async: true

  alias Fugue.Mood.{Fuzzify, MembershipState}

  setup do
    # Bypass the start_link/1 wrapper's default global name registration
    # (Fugue.Mood.MembershipState) so concurrent test runs don't collide.
    {:ok, pid} = GenServer.start_link(MembershipState, nil)
    %{pid: pid}
  end

  test "starts with the default membership func defs", %{pid: pid} do
    assert MembershipState.current(pid) == Fuzzify.default_membership_func_defs()
  end

  test "put/2 replaces state wholesale with no validation", %{pid: pid} do
    bogus = %{inputs: [], outputs: []}
    assert MembershipState.put(bogus, pid) == bogus
    assert MembershipState.current(pid) == bogus
  end
end
