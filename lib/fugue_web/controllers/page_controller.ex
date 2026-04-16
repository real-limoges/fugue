defmodule FugueWeb.PageController do
  use FugueWeb, :controller

  def home(conn, _params) do
    latest_post = Fugue.Blog.list_posts() |> List.first()
    render(conn, :home, latest_post: latest_post)
  end
end
