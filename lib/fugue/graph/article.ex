defmodule Fugue.Graph.Article do
  use Ecto.Schema

  @primary_key {:id, :integer, autogenerate: false}
  @timestamps_opts false

  schema "articles" do
    field(:title, :string)
    field(:abstract, :string)
    field(:is_disambiguation, :boolean, default: false)
    field(:timestamp, :string)
    field(:in_degree, :integer, default: 0)
    field(:out_degree, :integer, default: 0)
    field(:pagerank, :float, default: 0.0)
  end
end
