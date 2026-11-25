defmodule FugueWeb.LabLive.Index do
  @moduledoc """
  Landing page for /lab: small, separately-addressable statistical
  experiments. Rougher than the menagerie, narrower than a topic chapter.
  """

  use FugueWeb, :live_view

  import FugueWeb.IndexComponents

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto py-8">
      <.index_header kicker="lab" title="Statistical experiments">
        Stats ideas I wanted to see drawn out. Each one goes after a single
        thing about a model and stops there, so they're rougher than the rest
        of the site (on purpose, mostly), and there are two so far.
      </.index_header>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
        <.index_card
          href={~p"/lab/gam"}
          category="GAMLSS"
          title="Same scatter, three fits"
          accent="primary"
        >
          Four scatter plots with three fits stacked on each, and you get to
          watch each fit run out of road. A line only gets a slope. A GAM can
          bend to follow the average. A GAMLSS can also let the spread grow and
          shrink as you move along, which real data does basically all the time.
        </.index_card>

        <.index_card
          href={~p"/lab/bayes"}
          category="Bayesian"
          title="Three problems, three posteriors"
          accent="accent"
        >
          Lost keys, Bay Area earthquakes, and a yes-or-no call. Each one ends
          with a distribution over the thing you didn't know, and once you have
          that, every question you actually care about is an integral over it.
        </.index_card>
      </div>

      <.source_link repos={[{"fugue", "lib/fugue_web/live/lab"}]} />
    </div>
    """
  end
end
