defmodule Fugue.Graph.Category do
  use Ecto.Schema

  @primary_key {:id, :integer, autogenerate: false}
  @timestamps_opts false

  schema "categories" do
    field :name, :string
  end
end
