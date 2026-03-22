defmodule Fugue.Graph.Loader do
  @moduledoc """
  Loads graph data from CozoDB.
  """

  alias Fugue.Db
  alias Fugue.Graph.{Article, Link}

  @default_max_nodes 10_000

  def load_subgraph(seed_id, opts \\ []) do
    max_nodes = Keyword.get(opts, :max_nodes, @default_max_nodes)

    with {:ok, node_ids} <- bfs_expand(seed_id, max_nodes),
         {:ok, nodes} <- fetch_articles(node_ids),
         {:ok, links} <- fetch_links(node_ids) do
      {:ok, %{nodes: nodes, links: links}}
    end
  end

  def search_articles(query) do
    script = "?[id] := ~article:title_fts{id | query: $query, k: 100}"

    case Db.query(script, %{"query" => query}) do
      {:ok, results} ->
        {:ok, Enum.map(results, fn r -> r["id"] end)}

      {:error, _} = err ->
        err
    end
  end

  def get_article(id) do
    script = """
    ?[id, title, abstract, is_disambiguation, timestamp, in_degree, out_degree, pagerank] :=
      *article{id, title, abstract, is_disambiguation, timestamp, in_degree, out_degree, pagerank},
      id == $id
    """

    case Db.query(script, %{"id" => id}) do
      {:ok, [result]} ->
        {:ok, Article.from_map(result)}

      {:ok, []} ->
        {:error, :not_found}

      {:error, _} = err ->
        err
    end
  end

  # Private

  defp fetch_articles(ids) do
    id_rows = Enum.map(ids, fn id -> [id] end)

    script = """
    ids[id] <- $ids
    ?[id, title, abstract, is_disambiguation, timestamp, in_degree, out_degree, pagerank] :=
      ids[id],
      *article{id, title, abstract, is_disambiguation, timestamp, in_degree, out_degree, pagerank}
    """

    case Db.query(script, %{"ids" => id_rows}) do
      {:ok, results} ->
        {:ok, Enum.map(results, &Article.from_map/1)}

      {:error, _} = err ->
        err
    end
  end

  defp fetch_links(ids) do
    id_rows = Enum.map(ids, fn id -> [id] end)

    script = """
    ids[id] <- $ids
    ?[source, target, link_type] :=
      *links_to{source, target, link_type},
      ids[source],
      ids[target]
    """

    case Db.query(script, %{"ids" => id_rows}) do
      {:ok, results} ->
        {:ok, Enum.map(results, &Link.from_map/1)}

      {:error, _} = err ->
        err
    end
  end

  defp bfs_expand(seed_id, max_nodes) do
    script = """
    seed[x] <- [[$seed_id]]
    ?[node] := seed[node]
    ?[node] := seed[x], *links_to{source: x, target: node}
    ?[node] := seed[x], *links_to{source: x, target: mid}, *links_to{source: mid, target: node}
    :limit #{max_nodes}
    """

    case Db.query(script, %{"seed_id" => seed_id}) do
      {:ok, results} ->
        {:ok, Enum.map(results, fn r -> r["node"] end)}

      {:error, _} = err ->
        err
    end
  end
end
