defmodule Fugue.MembershipDefaults do
  @moduledoc """
  The menagerie's "reset to defaults" snapshot.
  """

  alias Fugue.Mood.Fuzzify

  @doc "Returns `{:ok, defs}`."
  def get, do: {:ok, Fuzzify.default_membership_func_defs()}
end
