defmodule Fugue.MembershipDefaults do
  @moduledoc """
  Lazy snapshot of the initial membership function definitions from Ish.
  The first caller triggers a fetch; the result is stored in `:persistent_term`
  and becomes the "reset to defaults" target for the menagerie. Uses
  `:persistent_term` instead of an Agent so there's no process to supervise --
  the snapshot survives code reloads and is readable from any process.
  """

  alias Fugue.Ish

  @key {__MODULE__, :snapshot}

  @doc """
  Returns the snapshot. On first call, fetches from Ish and stores it.
  Subsequent calls return the cached snapshot even if the live Ish state has
  been mutated since.
  """
  def get do
    case :persistent_term.get(@key, :miss) do
      :miss ->
        case Ish.membership_functions() do
          {:ok, defs} ->
            :persistent_term.put(@key, defs)
            {:ok, defs}

          err ->
            err
        end

      defs ->
        {:ok, defs}
    end
  end
end
