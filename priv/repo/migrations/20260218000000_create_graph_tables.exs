defmodule Fugue.Repo.Migrations.CreateGraphTables do
  use Ecto.Migration

  def up do
    create table(:articles, primary_key: false) do
      add :id, :integer, primary_key: true
      add :title, :text, null: false
      add :abstract, :text
      add :is_disambiguation, :integer, default: 0
      add :timestamp, :text
      add :in_degree, :integer, default: 0
      add :out_degree, :integer, default: 0
      add :pagerank, :float, default: 0.0
    end

    create index(:articles, [:title])
    create index(:articles, [:pagerank])

    execute """
    CREATE TABLE links (
      source_id INTEGER NOT NULL REFERENCES articles(id),
      target_id INTEGER NOT NULL REFERENCES articles(id),
      link_type TEXT DEFAULT 'LINKS_TO',
      PRIMARY KEY (source_id, target_id)
    )
    """

    create index(:links, [:source_id])
    create index(:links, [:target_id])

    create table(:categories, primary_key: false) do
      add :id, :integer, primary_key: true
      add :name, :text, null: false
    end

    create unique_index(:categories, [:name])

    execute """
    CREATE TABLE article_categories (
      article_id INTEGER NOT NULL REFERENCES articles(id),
      category_id INTEGER NOT NULL REFERENCES categories(id),
      PRIMARY KEY (article_id, category_id)
    )
    """

    create index(:article_categories, [:article_id])
    create index(:article_categories, [:category_id])

    execute """
    CREATE VIRTUAL TABLE articles_fts USING fts5(
      title, abstract,
      content='articles',
      content_rowid='id'
    )
    """
  end

  def down do
    execute "DROP TABLE IF EXISTS articles_fts"
    drop table(:article_categories)
    drop table(:categories)
    drop table(:links)
    drop table(:articles)
  end
end
