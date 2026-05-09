defmodule FugueWeb.Router do
  @moduledoc false
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
    get "/about", PageController, :about
    live "/mood", MoodLive
    live "/menagerie", MenagerieLive.Index
    live "/menagerie/fuzzy", MenagerieLive.Fuzzy
    live "/menagerie/mamdani", MenagerieLive.Mamdani
    live "/menagerie/boids", MenagerieLive.Boids
    live "/menagerie/quantum-walk", MenagerieLive.QuantumWalk
    live "/menagerie/quantum-stats", MenagerieLive.QuantumStats
    live "/menagerie/sandpile", MenagerieLive.Sandpile
    live "/clouds", CloudsLive
    live "/lab", LabLive.Index
    live "/lab/gam", LabLive.Gam
    live "/lab/bayes", LabLive.Bayes
    live "/color", ColorLive
  end
end
