defmodule Fugue.Graph.BlomEncoderTest do
  use ExUnit.Case, async: true

  alias Fugue.Graph.{Article, BlomEncoder, Link}

  @magic 0x424C4F4D
  @version 1
  @flag_has_labels 0x02

  test "encodes empty graph" do
    data = BlomEncoder.encode(%{nodes: [], links: []})

    assert <<
             @magic::little-unsigned-32,
             @version::little-unsigned-16,
             0::little-unsigned-32,
             0::little-unsigned-32,
             @flag_has_labels::little-unsigned-16,
             # empty string table: total_len = 0
             0::little-unsigned-32
           >> == data
  end

  test "encodes nodes without edges" do
    nodes = [
      %Article{id: 1, title: "Hello", pagerank: 0.5, in_degree: 3, out_degree: 2},
      %Article{id: 2, title: "World", pagerank: 0.25, in_degree: 1, out_degree: 0}
    ]

    data = BlomEncoder.encode(%{nodes: nodes, links: []})

    # Parse header
    <<
      @magic::little-unsigned-32,
      @version::little-unsigned-16,
      2::little-unsigned-32,
      0::little-unsigned-32,
      @flag_has_labels::little-unsigned-16,
      rest::binary
    >> = data

    # Parse string table
    <<
      total_len::little-unsigned-32,
      offset0::little-unsigned-32,
      offset1::little-unsigned-32,
      string_bytes::binary-size(total_len),
      rest2::binary
    >> = rest

    assert total_len == 10
    assert offset0 == 0
    assert offset1 == 5
    assert string_bytes == "HelloWorld"

    # Parse node data: ids, pageranks, degrees
    <<
      1::little-unsigned-32,
      2::little-unsigned-32,
      pr0::little-float-32,
      pr1::little-float-32,
      5::little-unsigned-16,
      1::little-unsigned-16
    >> = rest2

    assert_in_delta pr0, 0.5, 0.001
    assert_in_delta pr1, 0.25, 0.001
  end

  test "encodes edges" do
    nodes = [
      %Article{id: 10, title: "A", pagerank: 0.0, in_degree: 1, out_degree: 1},
      %Article{id: 20, title: "B", pagerank: 0.0, in_degree: 1, out_degree: 1}
    ]

    links = [%Link{source_id: 10, target_id: 20, link_type: "LINKS_TO"}]

    data = BlomEncoder.encode(%{nodes: nodes, links: links})

    # Skip to edge data: header(16) + string_table(4 + 2*4 + 2) + node_data(2*4 + 2*4 + 2*2)
    # string table: total_len(4) + offsets(8) + "AB"(2) = 14
    # node data: ids(8) + pageranks(8) + degrees(4) = 20
    # total offset: 16 + 14 + 20 = 50
    <<_::binary-size(50), edge_data::binary>> = data

    assert <<
             10::little-unsigned-32,
             20::little-unsigned-32
           >> = edge_data
  end

  test "degree caps at 65535" do
    node = %Article{id: 1, title: "", pagerank: 0.0, in_degree: 40_000, out_degree: 40_000}
    data = BlomEncoder.encode(%{nodes: [node], links: []})

    # Skip header(16) + string_table(4 + 4 + 0) + id(4) + pagerank(4)
    <<_::binary-size(32), degree::little-unsigned-16>> = data
    assert degree == 65535
  end

  test "handles nil fields with defaults" do
    node = %Article{id: 1, title: nil, pagerank: nil, in_degree: nil, out_degree: nil}
    data = BlomEncoder.encode(%{nodes: [node], links: []})

    <<
      @magic::little-unsigned-32,
      @version::little-unsigned-16,
      1::little-unsigned-32,
      0::little-unsigned-32,
      @flag_has_labels::little-unsigned-16,
      0::little-unsigned-32,
      0::little-unsigned-32,
      1::little-unsigned-32,
      pr::little-float-32,
      0::little-unsigned-16
    >> = data

    assert pr == 0.0
  end
end
