defmodule Fugue.Release do
  @app :fugue

  def migrate do
    load_app()
    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  defp repos, do: Application.fetch_env!(@app, :ecto_repos)

  defp load_app do
    Application.load(@app)
    for app <- Application.spec(@app, :applications) do
      Application.ensure_all_started(app)
    end
  end
end
