defmodule FugueWeb.CoreComponents do
  @moduledoc """
  The site's shared components: the per-page source footer, the per-figure
  "how this was made" line, and Heroicons. Imported into every view by
  `FugueWeb.html_helpers/0`.

  The Phoenix generator's form, table, flash and modal components were
  deleted on 2026-11-25: the site has no forms beyond sliders, no tables
  and no flash, and none of them was used. Bring one back from the
  generator if a page needs it.
  """
  use Phoenix.Component

  @github_owner "real-limoges"

  @doc """
  Renders the "source" footer that points a page at the repos behind it.

  Every page on this site is the front end of something public, so each one
  ends with a line naming what it's made of. Entries are either a bare repo
  name or a `{repo, path}` tuple to deep-link a directory. Paths resolve
  against `HEAD` so they follow the repo's default branch instead of
  hard-coding one.

  ## Examples

      <.source_link repos={["petri", {"fugue", "lib/fugue_web/live/clouds_live.ex"}]} />
  """
  attr :repos, :list,
    required: true,
    doc: ~s(repo specs: `"name"` or `{"name", "path/inside/repo"}`)

  attr :class, :string, default: nil

  def source_link(assigns) do
    assigns = assign(assigns, :links, Enum.map(assigns.repos, &source_repo/1))

    ~H"""
    <p class={[
      "mt-12 pt-4 border-t border-base-content/10 font-mono text-[11px] text-base-content/65 dark:text-base-content/40",
      @class
    ]}>
      <span class="uppercase tracking-[0.2em] text-base-content/60 dark:text-base-content/30">source</span>
      <span :for={{{name, url}, i} <- Enum.with_index(@links)} phx-no-format><span :if={i > 0} class="text-base-content/45 dark:text-base-content/20 px-1">/</span><a href={url} class="hover:text-primary underline decoration-dotted underline-offset-4 transition-colors">{name}</a></span>
    </p>
    """
  end

  @doc """
  Renders the "how this was made" line under a single splash figure.

  Different from `source_link/1`, which sits once at the foot of a page and
  names the repos wholesale. This one hangs off one figure and is aimed at a
  reader technical enough to want the trick behind what they're looking at,
  so `:note` should name the actual mechanism (the shader, the model, the
  dataset) rather than describe the picture. The link text is the bare
  filename, which is the part that reads as clickable to that reader.

  ## Examples

      <.figure_source
        note="thin-film interference over a swirling noise thickness map"
        repo={{"fugue", "assets/js/hooks/iridescence.js"}}
      />
  """
  attr :note, :string, required: true, doc: "the mechanism, in a few words"

  attr :repo, :any,
    required: true,
    doc: ~s(a repo spec: `"name"` or `{"name", "path/inside/repo"}`)

  def figure_source(assigns) do
    {name, url} = source_repo(assigns.repo)

    assigns =
      assign(assigns,
        url: url,
        label: source_label(assigns.repo, name)
      )

    ~H"""
    <p class="mt-2 font-mono text-[10px] leading-relaxed text-base-content/60 dark:text-base-content/30">
      {@note}
      <a
        href={@url}
        class="ml-1 text-base-content/70 dark:text-base-content/45 hover:text-primary underline decoration-dotted underline-offset-4 transition-colors"
      >
        -&gt; {@label}
      </a>
    </p>
    """
  end

  @doc "The GitHub URL of one of the site owner's repos."
  @spec repo_url(String.t()) :: String.t()
  def repo_url(name), do: "https://github.com/#{@github_owner}/#{name}"

  defp source_repo({name, path}), do: {name, repo_url(name) <> "/tree/HEAD/" <> path}
  defp source_repo(name) when is_binary(name), do: {name, repo_url(name)}

  defp source_label({_name, path}, _fallback), do: Path.basename(path)
  defp source_label(_spec, fallback), do: fallback

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles: outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  the compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end
end
