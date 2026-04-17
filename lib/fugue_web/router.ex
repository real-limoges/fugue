defmodule FugueWeb.Router do
  use FugueWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FugueWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", FugueWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/blog", BlogController, :index
    get "/blog/feed.xml", BlogController, :feed
    get "/blog/:slug", BlogController, :show
    live "/mood", MoodLive
    live "/menagerie", MenagerieLive.Index
    live "/menagerie/fuzzy", MenagerieLive.Fuzzy
    live "/menagerie/mamdani", MenagerieLive.Mamdani
    live "/menagerie/boids", MenagerieLive.Boids
    live "/menagerie/quantum-walk", MenagerieLive.QuantumWalk
    live "/menagerie/quantum-stats", MenagerieLive.QuantumStats
    live "/menagerie/sandpile", MenagerieLive.Sandpile
    live "/graph", GraphLive
  end
end
