defmodule Fugue.Graph.Article do
  @derive Jason.Encoder
  defstruct [
    :id,
    :title,
    :abstract,
    :is_disambiguation,
    :timestamp,
    :in_degree,
    :out_degree,
    :pagerank
  ]

  def from_map(m) when is_map(m) do
    %__MODULE__{
      id: extract_id(m["id"]),
      title: m["title"],
      abstract: m["abstract"],
      is_disambiguation: m["is_disambiguation"] || false,
      timestamp: m["timestamp"],
      in_degree: m["in_degree"] || 0,
      out_degree: m["out_degree"] || 0,
      pagerank: m["pagerank"] || 0.0
    }
  end

  defp extract_id("article:" <> id), do: id
  defp extract_id(id), do: id
end
