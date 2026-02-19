defmodule Fugue.Graph.ArticleCategory do
  use Ecto.Schema

  @primary_key false
  @timestamps_opts false

  schema "article_categories" do
    field :article_id, :integer
    field :category_id, :integer
  end
end
