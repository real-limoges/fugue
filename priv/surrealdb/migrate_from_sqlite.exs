# Migration script: SQLite → SurrealDB
#
# Prerequisites:
#   - SurrealDB running locally with schema imported
#   - SQLite database at priv/graph_data/fugue.db
#
# Usage:
#   mix run priv/surrealdb/migrate_from_sqlite.exs

sqlite_path = Path.join([__DIR__, "..", "graph_data", "fugue.db"])

unless File.exists?(sqlite_path) do
  IO.puts("SQLite database not found at #{sqlite_path}")
  System.halt(1)
end

{:ok, conn} = Exqlite.Sqlite3.open(sqlite_path)

# Helper to run a SQLite query and collect all rows
query_all = fn sql ->
  {:ok, stmt} = Exqlite.Sqlite3.prepare(conn, sql)

  rows =
    Stream.unfold(stmt, fn stmt ->
      case Exqlite.Sqlite3.step(conn, stmt) do
        {:row, row} -> {row, stmt}
        :done -> nil
      end
    end)
    |> Enum.to_list()

  Exqlite.Sqlite3.release(conn, stmt)
  rows
end

IO.puts("Migrating articles...")

articles = query_all.("SELECT id, title, abstract, is_disambiguation, timestamp, in_degree, out_degree, pagerank FROM articles")
IO.puts("  Found #{length(articles)} articles")

batch_size = 500

articles
|> Enum.chunk_every(batch_size)
|> Enum.with_index()
|> Enum.each(fn {batch, i} ->
  inserts =
    batch
    |> Enum.map(fn [id, title, abstract, is_disambig, ts, in_deg, out_deg, pr] ->
      title_escaped = String.replace(title || "", "'", "\\'")
      abstract_escaped = String.replace(abstract || "", "'", "\\'")

      """
      CREATE article:#{id} SET
        title = '#{title_escaped}',
        abstract = '#{abstract_escaped}',
        is_disambiguation = #{if is_disambig == 1, do: "true", else: "false"},
        timestamp = '#{ts || ""}',
        in_degree = #{in_deg || 0},
        out_degree = #{out_deg || 0},
        pagerank = #{pr || 0.0};
      """
    end)
    |> Enum.join("\n")

  Fugue.Db.query(inserts)
  IO.puts("  Batch #{i + 1} (#{length(batch)} articles)")
end)

IO.puts("Migrating categories...")

categories = query_all.("SELECT id, name FROM categories")
IO.puts("  Found #{length(categories)} categories")

categories
|> Enum.chunk_every(batch_size)
|> Enum.each(fn batch ->
  inserts =
    batch
    |> Enum.map(fn [id, name] ->
      name_escaped = String.replace(name || "", "'", "\\'")
      "CREATE category:#{id} SET name = '#{name_escaped}';"
    end)
    |> Enum.join("\n")

  Fugue.Db.query(inserts)
end)

IO.puts("Migrating links...")

links = query_all.("SELECT source_id, target_id, link_type FROM links")
IO.puts("  Found #{length(links)} links")

links
|> Enum.chunk_every(batch_size)
|> Enum.with_index()
|> Enum.each(fn {batch, i} ->
  inserts =
    batch
    |> Enum.map(fn [src, tgt, lt] ->
      "RELATE article:#{src}->links_to->article:#{tgt} SET link_type = '#{lt || "LINKS_TO"}';"
    end)
    |> Enum.join("\n")

  Fugue.Db.query(inserts)

  if rem(i, 10) == 0 do
    IO.puts("  Batch #{i + 1} (#{length(batch)} links)")
  end
end)

IO.puts("Migrating article_categories...")

article_cats = query_all.("SELECT article_id, category_id FROM article_categories")
IO.puts("  Found #{length(article_cats)} article-category relations")

article_cats
|> Enum.chunk_every(batch_size)
|> Enum.each(fn batch ->
  inserts =
    batch
    |> Enum.map(fn [aid, cid] ->
      "RELATE article:#{aid}->categorized_as->category:#{cid};"
    end)
    |> Enum.join("\n")

  Fugue.Db.query(inserts)
end)

Exqlite.Sqlite3.close(conn)
IO.puts("Migration complete!")
