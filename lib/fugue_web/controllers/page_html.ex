defmodule FugueWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use FugueWeb, :html

  embed_templates "page_html/*"

  @github "https://github.com/real-limoges"

  @doc """
  Repos that are actually running when you load a page here.

  `:pages` lists the routes each one shows up on, so `/code` and the
  per-page `source` footers stay in agreement. Keep this list honest: a
  repo only belongs here while it is being executed. The fuzzy math and
  the mood clustering were Haskell services (hazy, ish) until #74 folded
  them into `Fugue.Fuzzy` and `Fugue.Mood`, which is why neither is
  listed anymore.
  """
  def running do
    [
      %{
        name: "fugue",
        lang: "Elixir",
        blurb:
          "This site, and by now most of what's under it. Phoenix and LiveView, with the drawing done on the server rather than shipped to your browser as a pile of JavaScript. The fuzzy math and the mood clustering live here too; they used to be their own services until keeping them awake stopped being worth it.",
        pages: [{"all of it", "/"}]
      },
      %{
        name: "petri",
        lang: "C -> WASM",
        blurb:
          "Simulation kernels written in C and compiled to WASM, so the stepping happens in your browser at native-ish speed. Boids and sandpile are wired up here; there are a handful more in the repo that haven't found a page yet.",
        pages: [
          {"/menagerie/boids", "/menagerie/boids"},
          {"/menagerie/sandpile", "/menagerie/sandpile"}
        ]
      },
      %{
        name: "glissando",
        lang: "Rust -> WASM",
        blurb:
          "Fits generalized additive models. Loads on demand as a wasm blob, so the curve you're dragging is being refit in the tab, not on a server somewhere.",
        pages: [{"/lab/gam", "/lab/gam"}]
      },
      %{
        name: "Timbre",
        lang: "Python",
        blurb:
          "World Color Survey aggregation: every chip on the 40 hue by 8 lightness grid against the term speakers of a language actually reached for, and how many of them agreed. Tarahumara, Kalam, Nafaanra, and Walpiri so far. The output gets generated into an Elixir module rather than queried at runtime.",
        pages: [{"/color", "/color"}]
      },
      %{
        name: "real-complex",
        lang: "infra",
        blurb:
          "Cloud Run config, GitHub Actions, and the environment variables the deployed service actually reads. Nothing to look at.",
        pages: []
      }
    ]
  end

  @doc """
  Repos that exist and are public, but aren't wired into a page yet.

  Anything here is a promise I haven't kept. Move an entry into
  `running/0` when it starts serving a route, not when it starts working.
  """
  def in_the_shop do
    [
      %{
        name: "chirplet",
        lang: "Julia",
        blurb:
          "White-crowned sparrow song dialects as a continuous field rather than tidy regions on a map. Vendored into the assets folder already, waiting on the upstream pipeline to make something worth drawing.",
        pages: []
      }
    ]
  end

  attr :repo, :map, required: true

  def repo_row(assigns) do
    assigns = assign(assigns, :url, "#{@github}/#{assigns.repo.name}")

    ~H"""
    <li class="border-t border-base-content/10 pt-4">
      <div class="flex flex-wrap items-baseline gap-x-3 gap-y-1">
        <a
          href={@url}
          class="font-mono text-sm text-amber-300 hover:text-amber-200 underline decoration-dotted underline-offset-4"
        >
          {@repo.name}
        </a>
        <span class="font-mono text-[10px] uppercase tracking-[0.2em] text-base-content/40">
          {@repo.lang}
        </span>
      </div>

      <p class="mt-2 text-sm text-base-content/65 leading-relaxed max-w-2xl">
        {@repo.blurb}
      </p>

      <p
        :if={@repo.pages != []}
        class="mt-2 font-mono text-[11px] text-base-content/35"
        phx-no-format
      ><span :for={{{label, path}, i} <- Enum.with_index(@repo.pages)}><span :if={i > 0}>, </span><a href={path} class="hover:text-primary transition-colors">{label}</a></span></p>
    </li>
    """
  end
end
