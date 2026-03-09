defmodule FugueWeb.GarconLive do
  use FugueWeb, :live_view
  alias Fugue.Garcon.Loader

  @topics ~w(haskell_programming parsing)

  def mount(_params, _session, socket) do
    {:ok,
    socket
    |> assign(:topics, @topics)
    |> assign(:current_topic, :nil)
    |> assign(:search_query, "")
    }
  end
end
