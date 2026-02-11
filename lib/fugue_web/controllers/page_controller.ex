defmodule FugueWeb.PageController do
  use FugueWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
