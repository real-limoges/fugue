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
    live "/sandbox", SandboxLive.Index
    live "/sandbox/fuzzy", SandboxLive.Fuzzy
    live "/sandbox/mamdani", SandboxLive.Mamdani
    live "/sandbox/boids", SandboxLive.Boids
    live "/sandbox/quantum-walk", SandboxLive.QuantumWalk
    live "/sandbox/quantum-stats", SandboxLive.QuantumStats
    live "/sandbox/sandpile", SandboxLive.Sandpile
    live "/graph", GraphLive
  end
end
