defmodule FugueWeb.PageController do
  @moduledoc false
  use FugueWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def about(conn, _params) do
    render(conn, :about,
      page_title: "About",
      meta_description:
        "Who runs realcomplex.systems: Real Limoges, a machine learning engineer who builds emergent things out of unusual parts."
    )
  end
end
