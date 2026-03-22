defmodule Fugue.Graph.Link do
  @derive Jason.Encoder
  defstruct [:source_id, :target_id, :link_type]

  def from_map(m) when is_map(m) do
    %__MODULE__{
      source_id: m["source"] || m["source_id"],
      target_id: m["target"] || m["target_id"],
      link_type: m["link_type"] || "LINKS_TO"
    }
  end
end
