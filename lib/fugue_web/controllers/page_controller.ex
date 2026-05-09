defmodule FugueWeb.PageController do
  @moduledoc false
  use FugueWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
