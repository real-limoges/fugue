defmodule Fugue.Graph.BlomEncoder do
  @moduledoc """
  Encodes graph data into the BLOM binary format consumed by the Bloom WASM engine.

  Wire format (all little-endian):
    Header (16 bytes): magic u32, version u16, node_count u32, edge_count u32, flags u16
    String table (when HasLabels): total_len u32, offsets [u32; n], UTF-8 bytes
    Node data: ids [u32; n], pageranks [f32; n], degrees [u16; n]
    Edge data: sources [u32; n], targets [u32; n]
  """

  alias Fugue.Graph.{Article, Link}

  @magic 0x424C4F4D
  @version 1
  @flag_has_labels Bitwise.bsl(1, 1)

  @spec encode(%{nodes: [Article.t()], links: [Link.t()]}) :: binary()
  def encode(%{nodes: nodes, links: links}) do
    node_count = length(nodes)
    edge_count = length(links)
    flags = @flag_has_labels

    header = <<
      @magic::little-unsigned-32,
      @version::little-unsigned-16,
      node_count::little-unsigned-32,
      edge_count::little-unsigned-32,
      flags::little-unsigned-16
    >>

    string_table = encode_string_table(nodes)
    node_data = encode_node_data(nodes)
    edge_data = encode_edge_data(links)

    header <> string_table <> node_data <> edge_data
  end

  defp encode_string_table(nodes) do
    labels = Enum.map(nodes, fn %{title: title} -> title || "" end)
    encoded = Enum.map(labels, &:unicode.characters_to_binary/1)
    total_len = encoded |> Enum.map(&byte_size/1) |> Enum.sum()

    {offsets_bin, _} =
      Enum.reduce(encoded, {<<>>, 0}, fn label, {acc, offset} ->
        {acc <> <<offset::little-unsigned-32>>, offset + byte_size(label)}
      end)

    concat = IO.iodata_to_binary(encoded)

    <<total_len::little-unsigned-32>> <> offsets_bin <> concat
  end

  defp encode_node_data(nodes) do
    ids = for %{id: id} <- nodes, into: <<>>, do: <<id::little-unsigned-32>>

    pageranks =
      for %{pagerank: pr} <- nodes, into: <<>> do
        <<(pr || 0.0)::little-float-32>>
      end

    degrees =
      for %{degree: d} <- nodes, into: <<>> do
        deg = min(d || 0, 65535)
        <<deg::little-unsigned-16>>
      end

    ids <> pageranks <> degrees
  end

  defp encode_edge_data(links) do
    sources =
      for %{source_id: src} <- links, into: <<>>, do: <<src::little-unsigned-32>>

    targets =
      for %{target_id: tgt} <- links, into: <<>>, do: <<tgt::little-unsigned-32>>

    sources <> targets
  end
end
