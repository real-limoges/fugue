defmodule Fugue.Graph.Category do
  @derive Jason.Encoder
  defstruct [:id, :name]

  def from_map(m) when is_map(m) do
    %__MODULE__{
      id: extract_id(m["id"]),
      name: m["name"]
    }
  end

  defp extract_id("category:" <> id), do: id
  defp extract_id(id), do: id
end
