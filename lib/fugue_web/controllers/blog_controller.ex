defmodule FugueWeb.BlogController do
  @moduledoc """
  Index, show, and Atom feed for posts compiled into `Fugue.Blog` at
  build time. Posts are loaded from `priv/blog/` via `@external_resource`
  so adding a markdown file recompiles this module on the next request.
  """
  use FugueWeb, :controller

  def index(conn, params) do
    tag = params["tag"]
    posts = Fugue.Blog.list_posts(tag: tag)
    tags = Fugue.Blog.all_tags()

    conn
    |> assign(:page_title, "Blog")
    |> assign(:meta_description, "Blog posts from realcomplex.systems")
    |> render(:index, posts: posts, tags: tags, current_tag: tag)
  end

  def show(conn, %{"slug" => slug}) do
    case Fugue.Blog.get_post(slug) do
      {:ok, post} ->
        conn
        |> assign(:page_title, post.title)
        |> assign(:meta_description, post.summary)
        |> render(:show, post: post)

      :error ->
        conn
        |> put_status(:not_found)
        |> put_view(FugueWeb.ErrorHTML)
        |> render(:"404")
    end
  end

  def feed(conn, _params) do
    posts = Fugue.Blog.list_posts(limit: 20)
    xml = FugueWeb.BlogHTML.feed_xml(posts)

    conn
    |> put_resp_content_type("application/atom+xml")
    |> send_resp(200, xml)
  end
end
