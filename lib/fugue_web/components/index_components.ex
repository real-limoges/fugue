defmodule FugueWeb.IndexComponents do
  @moduledoc """
  The header and cards shared by the `/menagerie` and `/lab` index pages,
  and the header every menagerie page opens with.
  """
  use Phoenix.Component
  use FugueWeb, :verified_routes

  @doc """
  A menagerie page's back link and title. The slot holds the paragraphs
  under the title.
  """
  attr :title, :string, required: true
  slot :inner_block, required: true

  def menagerie_header(assigns) do
    ~H"""
    <nav class="mb-6 text-xs">
      <.link navigate={~p"/menagerie"} class="text-base-content/45 hover:text-base-content/75">
        ← Menagerie
      </.link>
    </nav>

    <div class="mb-4">
      <h1 class="text-2xl font-bold text-base-content">{@title}</h1>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc "The kicker, title and blurb at the top of an index page."
  attr :kicker, :string, required: true, doc: ~s(the path-like label, e.g. "menagerie")
  attr :title, :string, required: true
  slot :inner_block, required: true

  def index_header(assigns) do
    ~H"""
    <header class="mb-10">
      <p class="font-mono text-[10px] uppercase tracking-[0.25em] text-primary/60 mb-3">
        / {@kicker}
      </p>
      <h1 class="text-2xl font-mono font-semibold text-base-content mb-3">{@title}</h1>
      <p class="text-sm text-base-content/50 leading-relaxed max-w-2xl">
        {render_slot(@inner_block)}
      </p>
    </header>
    """
  end

  @doc "One linked card on an index page."
  attr :href, :string, required: true
  attr :category, :string, required: true
  attr :title, :string, required: true
  attr :accent, :string, required: true, values: ~w(primary accent secondary warning)
  slot :inner_block, required: true

  def index_card(assigns) do
    ~H"""
    <.link
      navigate={@href}
      class={[
        "group block rounded-lg border-t-2 bg-base-200 p-6 transition hover:bg-base-300",
        accent_border(@accent)
      ]}
    >
      <p class={["font-mono text-[10px] uppercase tracking-[0.2em] mb-3", accent_label(@accent)]}>
        {@category}
      </p>
      <h2 class="text-lg font-semibold text-base-content mb-2">{@title}</h2>
      <p class="text-sm text-base-content/50 leading-relaxed">
        {render_slot(@inner_block)}
      </p>
      <p class={["mt-4 font-mono text-[11px] transition", accent_cta(@accent)]}>
        explore &rarr;
      </p>
    </.link>
    """
  end

  defp accent_border("primary"), do: "border-primary"
  defp accent_border("accent"), do: "border-accent"
  defp accent_border("secondary"), do: "border-secondary"
  defp accent_border("warning"), do: "border-warning"

  defp accent_label("primary"), do: "text-primary/70"
  defp accent_label("accent"), do: "text-accent/70"
  defp accent_label("secondary"), do: "text-secondary/70"
  defp accent_label("warning"), do: "text-warning/70"

  # Full strength on light paper, where /50 falls near 2:1; dark keeps the
  # dim label that brightens on hover.
  defp accent_cta("primary"),
    do: "text-primary dark:text-primary/50 dark:group-hover:text-primary/90"

  defp accent_cta("accent"),
    do: "text-accent dark:text-accent/50 dark:group-hover:text-accent/90"

  defp accent_cta("secondary"),
    do: "text-secondary dark:text-secondary/50 dark:group-hover:text-secondary/90"

  defp accent_cta("warning"),
    do: "text-warning dark:text-warning/50 dark:group-hover:text-warning/90"
end
