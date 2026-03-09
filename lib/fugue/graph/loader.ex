defmodule Fugue.Graph.Loader do
  @moduledoc """
  Loads graph data from SQLite via Ecto.
  """

  import Ecto.Query
  alias Fugue.Repo
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
    case Repo.query("SELECT rowid FROM articles_fts WHERE articles_fts MATCH ? LIMIT 100", [query]) do
      {:ok, %{rows: rows}} -> {:ok, Enum.map(rows, fn [id] -> id end)}
      {:error, _} = err -> err
    end
  end

  def get_article(id) do
    case Repo.get(Article, id) do
      nil -> {:error, :not_found}
      article -> {:ok, article}
    end
  end

  # Private

  defp fetch_articles(ids) do
    articles = Repo.all(from(a in Article, where: a.id in ^ids))
    {:ok, articles}
  end

  defp fetch_links(ids) do
    links =
      Repo.all(
        from(l in Link,
          where: l.source_id in ^ids and l.target_id in ^ids
        )
      )

    {:ok, links}
  end

  defp bfs_expand(seed_id, max_nodes) do
    sql = """
    WITH RECURSIVE bfs(id, depth) AS (
      SELECT ?, 0
      UNION
      SELECT l.target_id, bfs.depth + 1
      FROM links l
      JOIN bfs ON l.source_id = bfs.id
      WHERE bfs.depth < 2
    )
    SELECT DISTINCT id FROM bfs LIMIT ?
    """

    case Repo.query(sql, [seed_id, max_nodes]) do
      {:ok, %{rows: rows}} -> {:ok, Enum.map(rows, fn [id] -> id end)}
      {:error, _} = err -> err
    end
  end
end
