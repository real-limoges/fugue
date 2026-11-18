defmodule FugueWeb.ErrorHTML do
  @moduledoc """
  Renders error pages for HTML requests (see `render_errors` in
  `config/config.exs`).

  404 and 500 have templates in `error_html/`, drawn inside the site's root
  layout so the nav and footer are still there. Any other status falls back
  to its bare status message ("Bad Request" for 400).
  """
  use FugueWeb, :html

  embed_templates "error_html/*"

  @spec render(String.t(), map()) :: String.t()
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
