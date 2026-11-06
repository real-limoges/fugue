defmodule Fugue.Amigos.Connection do
  @moduledoc """
  One link from an `/amigos` layer to elsewhere: back to an earlier episode
  (`:callback`), ahead to a later one (`:foreshadowing`), or within this
  episode (`:internal`, which has no `target`).
  """

  @enforce_keys [:direction, :target, :note]
  defstruct [:direction, :target, :note]

  @type direction :: :callback | :foreshadowing | :internal

  @type t :: %__MODULE__{
          direction: direction(),
          target: String.t() | nil,
          note: String.t()
        }
end
