defmodule Fugue.Graph.Link do
  use Ecto.Schema

  @primary_key false
  @timestamps_opts false

  schema "links" do
    field(:source_id, :integer)
    field(:target_id, :integer)
    field(:link_type, :string, default: "LINKS_TO")
  end
end
