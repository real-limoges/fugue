defmodule Fugue.Graph.Link do
  @derive Jason.Encoder
  defstruct [:source_id, :target_id]

  def from_map(m) when is_map(m) do
    %__MODULE__{
      source_id: m["from_id"],
      target_id: m["to_id"]
    }
  end
end
