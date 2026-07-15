defmodule FugueWeb.LabLive.Index do
  @moduledoc """
  Landing page for /lab: small, separately-addressable statistical
  experiments. Rougher than the menagerie, narrower than a topic chapter.
  """

  use FugueWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto py-8">
      <header class="mb-10">
        <p class="font-mono text-[10px] uppercase tracking-[0.25em] text-primary/60 mb-3">
          / lab
        </p>
        <h1 class="text-2xl font-mono font-semibold text-base-content mb-3">
          Statistical experiments
        </h1>
        <p class="text-sm text-base-content/50 leading-relaxed max-w-2xl">
          Small pieces, each one going after a single thing about a model.
          Rougher than a topic page; rougher on purpose. Two so far.
        </p>
      </header>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
        <.card
          href={~p"/lab/gam"}
          category="GAMLSS"
          title="Same scatter, three fits"
          accent="primary"
        >
          Four datasets, one habit: stack a line, a GAM, and a GAMLSS over the
          same points and watch what each layer can and can't say. The line is
          the floor; the GAM bends to the mean; the GAMLSS lets the spread bend
          with it.
        </.card>

        <.card
          href={~p"/lab/bayes"}
          category="Bayesian"
          title="Three problems, three posteriors"
          accent="accent"
        >
          A search, a rate, a decision. Each one ends with a distribution over
          the thing you didn't know, and any question you had about it becomes
          an integral over that distribution. That's the whole framework.
        </.card>
      </div>
    </div>
    """
  end

  attr :href, :string, default: nil
  attr :category, :string, required: true
  attr :title, :string, required: true
  attr :accent, :string, required: true, values: ~w(primary accent secondary warning)
  slot :inner_block, required: true

  defp card(%{href: nil} = assigns) do
    ~H"""
    <div class={[
      "block rounded-lg border-t-2 bg-base-200 p-6 opacity-60",
      accent_border(@accent)
    ]}>
      <p class={["font-mono text-[10px] uppercase tracking-[0.2em] mb-3", accent_label(@accent)]}>
        {@category}
      </p>
      <h2 class="text-lg font-semibold text-base-content mb-2">{@title}</h2>
      <p class="text-sm text-base-content/50 leading-relaxed">
        {render_slot(@inner_block)}
      </p>
      <p class="mt-4 font-mono text-[11px] text-base-content/30">
        coming soon
      </p>
    </div>
    """
  end

  defp card(assigns) do
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

  defp accent_cta("primary"), do: "text-primary/50 group-hover:text-primary/90"
  defp accent_cta("accent"), do: "text-accent/50 group-hover:text-accent/90"
  defp accent_cta("secondary"), do: "text-secondary/50 group-hover:text-secondary/90"
  defp accent_cta("warning"), do: "text-warning/50 group-hover:text-warning/90"
end
