defmodule Fugue.Graph.Loader do
  @moduledoc """
  Loads graph data from SurrealDB.
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
    sql = "SELECT id FROM article WHERE title @@ $query LIMIT 100"

    case Db.query(sql, %{"query" => query}) do
      {:ok, [%{"status" => "OK", "result" => results}]} ->
        {:ok, Enum.map(results, fn r -> extract_id(r["id"]) end)}

      {:ok, _} ->
        {:ok, []}

      {:error, _} = err ->
        err
    end
  end

  def get_article(id) do
    case Db.select("article:#{id}") do
      {:ok, [result]} when is_map(result) ->
        {:ok, Article.from_map(result)}

      {:ok, result} when is_map(result) ->
        {:ok, Article.from_map(result)}

      {:ok, []} ->
        {:error, :not_found}

      {:ok, nil} ->
        {:error, :not_found}

      {:error, _} = err ->
        err
    end
  end

  # Private

  defp fetch_articles(ids) do
    surreal_ids = Enum.map(ids, &to_surreal_id("article", &1))

    sql = "SELECT * FROM article WHERE id INSIDE $ids"

    case Db.query(sql, %{"ids" => surreal_ids}) do
      {:ok, [%{"status" => "OK", "result" => results}]} ->
        {:ok, Enum.map(results, &Article.from_map/1)}

      {:ok, _} ->
        {:ok, []}

      {:error, _} = err ->
        err
    end
  end

  defp fetch_links(ids) do
    surreal_ids = Enum.map(ids, &to_surreal_id("article", &1))

    sql =
      "SELECT *, in AS source_id, out AS target_id FROM links_to WHERE in INSIDE $ids AND out INSIDE $ids"

    case Db.query(sql, %{"ids" => surreal_ids}) do
      {:ok, [%{"status" => "OK", "result" => results}]} ->
        {:ok, Enum.map(results, &Link.from_map/1)}

      {:ok, _} ->
        {:ok, []}

      {:error, _} = err ->
        err
    end
  end

  defp bfs_expand(seed_id, max_nodes) do
    bfs_sql = """
    LET $seed = [article:#{seed_id}];
    LET $hop1 = SELECT VALUE ->links_to->article FROM $seed;
    LET $hop1_flat = array::flatten($hop1);
    LET $hop2 = SELECT VALUE ->links_to->article FROM $hop1_flat;
    LET $hop2_flat = array::flatten($hop2);
    LET $all = array::distinct(array::concat(array::concat($seed, $hop1_flat), $hop2_flat));
    RETURN array::slice($all, 0, $max_nodes);
    """

    case Db.query(bfs_sql, %{"max_nodes" => max_nodes}) do
      {:ok, results} ->
        # The RETURN statement result is the last element
        ids =
          results
          |> List.last()
          |> then(fn
            %{"status" => "OK", "result" => result} when is_list(result) ->
              Enum.map(result, &extract_id/1)

            %{"result" => result} when is_list(result) ->
              Enum.map(result, &extract_id/1)

            _ ->
              []
          end)

        {:ok, Enum.take(ids, max_nodes)}

      {:error, _} = err ->
        err
    end
  end

  defp extract_id("article:" <> id), do: id
  defp extract_id(id), do: id

  defp to_surreal_id("article", id), do: "article:#{id}"
  defp to_surreal_id(table, id), do: "#{table}:#{id}"
end
