defmodule FugueWeb.Layouts do
  @moduledoc """
  The site chrome: `root.html.heex` (head, header nav, footer) wraps every
  page, LiveView and controller alike, and the components here are the
  pieces of it that carry logic.
  """
  use FugueWeb, :html

  embed_templates "layouts/*"

  @doc """
  Renders one header nav link, marked as the current page when the request
  is on that section.

  A section is the link's path and everything under it, so `/menagerie/boids`
  marks the Menagerie link. The mark is `aria-current="page"`, and the
  styling hangs off that attribute, so what a screen reader hears and what
  the eye sees cannot drift apart.

  ## Examples

      <.nav_link href="/mood" current_path={@conn.request_path}>Mood</.nav_link>
  """
  attr :href, :string, required: true
  attr :current_path, :string, required: true, doc: "the request path being rendered"
  slot :inner_block, required: true

  def nav_link(assigns) do
    assigns = assign(assigns, :current?, in_section?(assigns.current_path, assigns.href))

    ~H"""
    <a
      href={@href}
      aria-current={@current? && "page"}
      class="btn btn-ghost btn-sm font-mono text-xs tracking-wider uppercase aria-[current=page]:text-primary aria-[current=page]:underline aria-[current=page]:decoration-2 aria-[current=page]:underline-offset-4"
    >
      {render_slot(@inner_block)}
    </a>
    """
  end

  @doc """
  Whether `path` is the section at `section_path` or a page under it.

  ## Examples

      iex> FugueWeb.Layouts.in_section?("/menagerie/boids", "/menagerie")
      true

      iex> FugueWeb.Layouts.in_section?("/moodboard", "/mood")
      false
  """
  @spec in_section?(String.t(), String.t()) :: boolean()
  def in_section?(path, section_path) do
    path == section_path or String.starts_with?(path, section_path <> "/")
  end

  @doc """
  The absolute URL of the page being rendered, for `og:url` and the
  canonical link. Built from the endpoint's configured URL, so it names the
  public host in production rather than whatever host the request came in
  on. The query string is dropped.
  """
  @spec page_url(Plug.Conn.t()) :: String.t()
  def page_url(conn), do: FugueWeb.Endpoint.url() <> conn.request_path

  @doc """
  Renders the banners shown while the LiveView socket is down.

  Both start hidden. LiveView puts `phx-client-error` (the browser lost the
  connection) or `phx-server-error` (the server side of the view crashed) on
  the page's main view container and takes it off on reconnect; a rule in
  `app.css` shows the matching banner while that class is present. Pages
  with no LiveView never get the classes, so they never show a banner.
  """
  def connection_status(assigns) do
    ~H"""
    <div class="toast toast-top toast-end z-50" aria-live="polite">
      <div id="client-error" class="alert alert-error hidden" role="alert">
        <.connection_message title="Lost the connection" />
      </div>
      <div id="server-error" class="alert alert-error hidden" role="alert">
        <.connection_message title="Something broke on the server" />
      </div>
    </div>
    """
  end

  attr :title, :string, required: true

  defp connection_message(assigns) do
    ~H"""
    <div class="font-mono text-xs">
      <p class="font-semibold">{@title}</p>
      <p>
        Reconnecting <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </p>
    </div>
    """
  end
end
