defmodule Fugue.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        FugueWeb.Telemetry,
        {DNSCluster, query: Application.get_env(:fugue, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: Fugue.PubSub}
      ] ++
        if Application.get_env(:fugue, :start_db, true) do
          [{Fugue.Db, Application.get_env(:fugue, Fugue.Db)}]
        else
          []
        end ++
        [FugueWeb.Endpoint]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Fugue.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FugueWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
