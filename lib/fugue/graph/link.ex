defmodule Fugue.Graph.Link do
  @derive Jason.Encoder
  defstruct [:source_id, :target_id, :link_type]

  def from_map(m) when is_map(m) do
    %__MODULE__{
      source_id: extract_id(m["in"] || m["source_id"]),
      target_id: extract_id(m["out"] || m["target_id"]),
      link_type: m["link_type"] || "LINKS_TO"
    }
  end

  defp extract_id("article:" <> id), do: id
  defp extract_id(id), do: id
end
