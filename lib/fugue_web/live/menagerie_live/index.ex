defmodule FugueWeb.MenagerieLive.Index do
  @moduledoc """
  Landing page for /menagerie -- a thin index that points at the individual
  math-exploration experiments.
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
          / menagerie
        </p>
        <h1 class="text-2xl font-mono font-semibold text-base-content mb-3">Math playgrounds</h1>
        <p class="text-sm text-base-content/50 leading-relaxed max-w-2xl">
          Self-contained experiments. Drag sliders, break things, see what falls out.
        </p>
      </header>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
        <.card
          href={~p"/menagerie/fuzzy"}
          category="Fuzzy logic"
          title="Triangular temperature bands"
          accent="primary"
        >
          Reshape triangular membership bands over four years of Melbourne daily
          temperatures. Every day holds partial membership in five overlapping
          fuzzy sets at once -- drag the sliders to see the gradient reshape.
        </.card>

        <.card
          href={~p"/menagerie/mamdani"}
          category="Fuzzy logic"
          title="Mamdani fan controller"
          accent="primary"
        >
          An old-school rule of thumb wired up as a fuzzy controller: hot and
          humid means run hard, cold means off. Watch seven weighted rules fire
          in real time and turn two crisp inputs into a crisp fan speed.
        </.card>

        <.card
          href={~p"/menagerie/boids"}
          category="Flocking"
          title="Boids playground"
          accent="accent"
        >
          Each bird follows three simple rules -- separate from neighbors, align
          with them, cohere toward the flock. Drag the force sliders and watch
          tight flocks form, schools stream past each other, or the whole crowd
          dissolve into chaos.
        </.card>

        <.card
          href={~p"/menagerie/quantum-walk"}
          category="Quantum"
          title="Classical vs quantum walk"
          accent="secondary"
        >
          Two walkers start at the center. The classical one drifts into a bell;
          the quantum one races out into two horns at the edges. A decoherence
          slider blends one into the other -- the dial that turns quantum back
          into classical.
        </.card>

        <.card
          href={~p"/menagerie/quantum-stats"}
          category="Quantum"
          title="Three ways to count"
          accent="secondary"
        >
          Three curves on one chart, one for each rule particles can follow
          about whether they're allowed to share a state. Drag the temperature:
          hot and they lie right on top of each other, cold and they peel into
          three dramatically different shapes.
        </.card>

        <.card
          href={~p"/menagerie/sandpile"}
          category="Self-organized criticality"
          title="Abelian sandpile"
          accent="warning"
        >
          Drop grains onto a grid. When a cell hits four it topples, cascading
          to neighbors. The system tunes itself to a critical state -- avalanche
          sizes follow a power law that nobody programmed in. Watch the
          log-log histogram converge to a straight line as grains accumulate.
        </.card>
      </div>
    </div>
    """
  end

  attr :href, :string, required: true
  attr :category, :string, required: true
  attr :title, :string, required: true
  attr :accent, :string, required: true, values: ~w(primary accent secondary warning)
  slot :inner_block, required: true

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
