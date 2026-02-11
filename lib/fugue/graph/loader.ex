defmodule Fugue.Graph.Loader do
  @moduledoc """
  Loads graph data from SQLite files
  """

  def load_topic(topic) do
    db_path = graph_db_path(topic)
    {:ok, conn} = Exqlite.Sqlite3.open(db_path)

    {:ok, statement} = Exqlite.Sqlite3.prepare(conn, """
      select id, title, x, y, size, color, categories, summary
      from nodes
      limit 10000
    """)

    nodes =
      Exqlite.Sqlite3.fetch_all(conn, statement)
      |> Enum.map(fn [id, title, x, y, size, color, categories, summary] ->
        %{
          id: id,
          label: title,
          x: x,
          y: y,
          size: size,
          color: parse_color(color),
          categories: Jason.decode!(categories),
          summary: summary
        }
      end)

    {:ok, statement} = Exqlite.Sqlite3.prepare(conn, """
      select source_id, target_id
      from edges
      where source_id in (select id from nodes limit 10000)
        and target_id in (select id from nodes limit 10000)
    """)

    links =
      Exqlite.Sqlite3.fetch_all(conn, statement)
      |> Enum.map(fn [source, target] ->
        %{source: source, target: target}
      end)

      Exqlite.Sqlite3.close(conn)

    {:ok, %{nodes: nodes, links: links}}
  end

  def search_subgraph(topic, query) do
    db_path = graph_db_path(topic)
    {:ok, conn} = Exqlite.Sqlite3.open(db_path)

    {:ok, statement} = Exqlite.Sqlite3.prepare(conn, """
      select id from nodes
      where title like ?
      limit 100
    """)

    matching_ids =
      Exqlite.Sqlite3.fetch_all(conn, statement, ["%#{query}%"])
      |> Enum.map(fn [id] -> id end)

    Exqlite.Sqlite3.close(conn)

    {:ok, %{matching_ids: matching_ids}}
  end
  def get_node_details(topic, node_id) do
    db_path = graph_db_path(topic)
    {:ok, conn} = Exqlite.Sqlite3.open(db_path)

    {:ok, statement} = Exqlite.Sqlite3.prepare(conn, """
      select title, categories, summary
      from nodes
      where id = ?
    """)

    case Exqlite.Sqlite3.fetch_all(conn, statement, [node_id]) do
      {:ok, [[title, categories, summary]]} ->
        Exqlite.Sqlite3.close(conn)
        {:ok, %{
          title: title,
          categories: Jason.decode!(categories),
          summary: summary
        }}

      {:ok, []} ->
        Exqlite.Sqlite3.close(conn)
        {:error, :not_found}

      {:error, reason} ->
        Exqlite.Sqlite3.close(conn)
        {:error, reason}
    end
  end

  defp graph_db_path(topic) do
    Path.join([Application.app_dir(:dedalus, "priv"), "graph_data", "#{topic}.db"])
  end

  defp parse_color(color_string) do
    # Assuming color stored as "r,g,b"
    [r, g, b] = String.split(color_string, ",") |> Enum.map(&String.to_integer/1)
    [r, g, b]
  end
end