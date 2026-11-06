defmodule Fugue.Amigos.Layer do
  @moduledoc """
  One group of stacking gags on the `/amigos` page: its scroll `beats`,
  whether the ending's counter admits to it (`counted`), and its
  `connections`. The rows themselves live in `Fugue.Amigos`.
  """

  alias Fugue.Amigos.Connection

  @enforce_keys [:id, :name, :summary, :beats, :counted, :connections]
  defstruct [:id, :name, :summary, :beats, :counted, :connections]

  @type t :: %__MODULE__{
          id: atom(),
          name: String.t(),
          summary: String.t(),
          beats: [pos_integer(), ...],
          counted: boolean(),
          connections: [Connection.t()]
        }
end
