defmodule Fugue.Graph.Loader do
  @moduledoc """
  Loads graph data from CozoDB.

  The schema is produced by Dedalus (`src/cozo_writer.rs`):

      article   { id: Int => title: String, pagerank: Float?, community: Int?, degree: Int? }
      links_to  { from_id: Int, to_id: Int }

  No FTS index exists, so title search falls back to a lowercase substring
  scan — fine for the tiny topic list but would need rework for large queries.
  """

  alias Fugue.Db
  alias Fugue.Graph.{Article, Link}

  @default_max_nodes 500

  def load_subgraph(seed_id, opts \\ []) do
    max_nodes = Keyword.get(opts, :max_nodes, @default_max_nodes)

    with {:ok, node_ids} <- bfs_expand(seed_id, max_nodes),
         {:ok, nodes} <- fetch_articles(node_ids),
         {:ok, links} <- fetch_links(node_ids) do
      {:ok, %{nodes: nodes, links: links}}
    end
  end

  @doc """
  Returns article ids whose (lowercased) title contains the query.
  No FTS index exists, so this is a linear scan; cap at 50 hits and rely on
  short queries from the search box for acceptable latency.
  """
  def search_articles(query) when is_binary(query) do
    needle = String.downcase(query)

    script = """
    ?[id, title] :=
      *article{id, title},
      str_includes(lowercase(title), $needle)
    :limit 50
    """

    case Db.query(script, %{"needle" => needle}) do
      {:ok, results} ->
        {:ok, Enum.map(results, fn r -> r["id"] end)}

      {:error, _} = err ->
        err
    end
  end

  @doc """
  Resolves an exact article title to its id. Used by topic loading so we can
  skip the full substring scan on the hot path.
  """
  def lookup_by_title(title) when is_binary(title) do
    script = """
    ?[id] := *article{id, title}, title == $title
    """

    case Db.query(script, %{"title" => title}) do
      {:ok, [%{"id" => id}]} -> {:ok, id}
      {:ok, []} -> {:error, :not_found}
      {:error, _} = err -> err
    end
  end

  def get_article(id) when is_integer(id) do
    script = """
    ?[id, title, pagerank, community, degree] :=
      *article{id, title, pagerank, community, degree},
      id == $id
    """

    case Db.query(script, %{"id" => id}) do
      {:ok, [result]} -> {:ok, Article.from_map(result)}
      {:ok, []} -> {:error, :not_found}
      {:error, _} = err -> err
    end
  end

  # Private

  defp fetch_articles([]), do: {:ok, []}

  defp fetch_articles(ids) do
    id_rows = Enum.map(ids, fn id -> [id] end)

    script = """
    ids[id] <- $ids
    ?[id, title, pagerank, community, degree] :=
      ids[id],
      *article{id, title, pagerank, community, degree}
    """

    case Db.query(script, %{"ids" => id_rows}) do
      {:ok, results} -> {:ok, Enum.map(results, &Article.from_map/1)}
      {:error, _} = err -> err
    end
  end

  defp fetch_links([]), do: {:ok, []}

  defp fetch_links(ids) do
    id_rows = Enum.map(ids, fn id -> [id] end)

    # Bind `from_id` from the in-memory ids set first so Cozo can probe the
    # stored relation by primary key instead of scanning every edge.
    script = """
    ids[id] <- $ids
    ?[from_id, to_id] :=
      ids[from_id],
      *links_to{from_id, to_id},
      ids[to_id]
    """

    case Db.query(script, %{"ids" => id_rows}) do
      {:ok, results} -> {:ok, Enum.map(results, &Link.from_map/1)}
      {:error, _} = err -> err
    end
  end

  # Fetches the seed plus its 1-hop out-neighbors. Recursive multi-hop
  # expansion is too slow on a multi-billion-edge graph — Cozo materializes
  # the full fixed point before `:limit` kicks in. A direct index probe on
  # `from_id` caps work at the seed's fan-out.
  defp bfs_expand(seed_id, max_nodes) do
    script = """
    ?[node] := node = $seed_id
    ?[node] := *links_to{from_id: $seed_id, to_id: node}
    :limit #{max_nodes}
    """

    case Db.query(script, %{"seed_id" => seed_id}) do
      {:ok, results} -> {:ok, Enum.map(results, fn r -> r["node"] end)}
      {:error, _} = err -> err
    end
  end
end
