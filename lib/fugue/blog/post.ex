defmodule Fugue.Blog.Post do
  @moduledoc false
  @enforce_keys [:slug, :title, :date, :body, :tags, :summary, :draft]
  defstruct [:slug, :title, :date, :body, :tags, :summary, :draft]
end
