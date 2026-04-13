defmodule Fugue.Graph.Article do
  @derive Jason.Encoder
  defstruct [:id, :title, :pagerank, :community, :degree]

  def from_map(m) when is_map(m) do
    %__MODULE__{
      id: m["id"],
      title: m["title"],
      pagerank: m["pagerank"] || 0.0,
      community: m["community"],
      degree: m["degree"] || 0
    }
  end
end
