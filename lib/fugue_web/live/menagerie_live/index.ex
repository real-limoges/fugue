defmodule FugueWeb.MenagerieLive.Index do
  @moduledoc """
  Landing page for /menagerie: a thin index that points at the individual
  math-exploration experiments.
  """

  use FugueWeb, :live_view

  import FugueWeb.IndexComponents

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto py-8">
      <.index_header kicker="menagerie" title="Math playgrounds">
        Little sims to poke at. Most of them are a couple of simple rules
        run thousands of times, and the sliders are there so you can break
        them (please do, nothing here minds).
      </.index_header>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
        <.index_card
          href={~p"/menagerie/fuzzy"}
          category="Fuzzy logic"
          title="Triangular temperature bands"
          accent="primary"
        >
          Four years of Melbourne weather sorted into cold, cool, mild, warm and
          hot, except no day has to pick just one. Drag the sliders and every
          day in the dataset gets re-sorted at once.
        </.index_card>

        <.index_card
          href={~p"/menagerie/mamdani"}
          category="Fuzzy logic"
          title="Mamdani fan controller"
          accent="primary"
        >
          An old-school rule of thumb (hot and sticky, crank the fan; cold,
          turn it off), written down as seven fuzzy rules. Move the
          temperature and humidity and watch each rule vote on how fast the
          fan should spin.
        </.index_card>

        <.index_card
          href={~p"/menagerie/boids"}
          category="Flocking"
          title="Boids playground"
          accent="accent"
        >
          Each bird knows three things (don't crowd your neighbors, point where
          they're pointing, stay near the group) and nothing about the flock as
          a whole. Push the sliders and it tightens up, streams past itself like
          a school of fish, or falls apart completely.
        </.index_card>

        <.index_card
          href={~p"/menagerie/quantum-walk"}
          category="Quantum"
          title="Classical vs quantum walk"
          accent="secondary"
        >
          Two walkers start in the middle and flip coins. The normal one ends up
          in a bell curve, like you'd expect; the quantum one ends up mostly at
          the two far edges, which nobody expects the first time. One slider
          drains the quantum back out.
        </.index_card>

        <.index_card
          href={~p"/menagerie/quantum-stats"}
          category="Quantum"
          title="Three ways to count"
          accent="secondary"
        >
          Particles follow one of three rules about sharing a spot, and when
          it's hot you honestly can't tell which. Cool things down and the three
          curves come apart into shapes that look like they belong to different
          problems.
        </.index_card>

        <.index_card
          href={~p"/menagerie/sandpile"}
          category="Self-organized criticality"
          title="Abelian sandpile"
          accent="warning"
        >
          Drop sand on a grid; any cell holding four grains tips over onto its
          neighbors, which can tip over theirs, and so on. Nobody tells the pile
          how big its avalanches should be, and the histogram straightens into a
          power law anyway.
        </.index_card>
      </div>

      <.source_link repos={["petri", {"fugue", "lib/fugue_web/live/menagerie_live"}]} />
    </div>
    """
  end
end
