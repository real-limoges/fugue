defmodule FugueWeb.MoodLive.Sections do
  @moduledoc """
  Function components for each chapter of the /mood page. The LiveView module
  (`FugueWeb.MoodLive`) owns state, push_event payloads, and handle_event
  callbacks; this module owns the markup so render/1 there stays short and the
  chapters are individually readable.
  """

  use Phoenix.Component

  alias FugueWeb.MoodLive.{
    AmbiguityHistogram,
    CalendarGrid,
    ClusterRadar,
    DateRange,
    DimensionDistributions,
    DimensionDrift,
    GapAnalysis,
    MoodFlowers,
    MoodTrajectory,
    MoodTransitions,
    SeasonRing,
    StreamGraph,
    TransitionSankey,
    TransitionTimeline
  }

  attr :stats, :map, required: true
  attr :trajectory_points, :list, default: []
  attr :trajectory_annotations, :list, default: []
  attr :analysis, :map, required: true
  attr :selected_day, :any, default: nil

  def hero(assigns) do
    ~H"""
    <section class="mb-20 -mx-4 md:-mx-8">
      <div class="bg-black/40 border-y border-white/5 py-10 px-4 md:px-8">
        <div class="max-w-5xl mx-auto">
          <MoodTrajectory.trajectory
            points={@trajectory_points}
            annotations={@trajectory_annotations}
            cluster_colors={@analysis.cluster_colors}
            cluster_names={@analysis.cluster_names}
            selected_day={@selected_day}
          />

          <div class="mt-8 max-w-xl ml-auto border-t border-white/10 pt-5 text-[11px] leading-relaxed text-gray-400 font-serif">
            <div class="uppercase tracking-[0.2em] text-[10px] text-gray-500 mb-1">
              Wall text
            </div>
            <div class="text-gray-200 text-sm mb-1 italic">
              Four Years, One Line
            </div>
            <div class="text-gray-500 mb-3">
              {DateRange.format(@stats.date_range)} &middot; PCA projection on daily self-ratings &middot; real limoges
            </div>
            <p class="mb-2">
              Every night before bed for four years; five numbers about how the day went. This is all of them, flattened onto 2D by PCA. Five dimensions don't fit on a screen and two do, so some of it is gone.
            </p>
            <p>
              One dot per day, connected in the order they happened. Colors come from clustering, painted back onto the path after the fact. I didn't pick the shape it makes. I can't tell you where it goes next.
            </p>
          </div>
        </div>
      </div>
    </section>
    """
  end

  attr :analysis, :map, required: true
  attr :selected_cluster, :any, default: nil

  def sticky_legend(assigns) do
    ~H"""
    <div class="sticky top-16 z-30 -mx-4 md:-mx-8 mb-12 backdrop-blur-md bg-base-100/85 border-y border-white/10">
      <div class="max-w-6xl mx-auto px-4 py-2 flex flex-wrap items-center gap-x-3 gap-y-1.5">
        <span class="text-[10px] uppercase tracking-[0.18em] text-gray-500 mr-1">
          States
        </span>
        <%= for cluster <- @analysis.clusters do %>
          <button
            phx-click="cluster_selected"
            phx-value-cluster={cluster["id"]}
            class={"inline-flex items-center gap-1.5 text-xs cursor-pointer transition-opacity #{if @selected_cluster && @selected_cluster != cluster["id"], do: "opacity-30 hover:opacity-100", else: "opacity-100"}"}
          >
            <span
              class="inline-block w-2.5 h-2.5 rounded-full"
              style={"background: #{Map.get(@analysis.cluster_colors, cluster["id"], "#666")}"}
            >
            </span>
            <span class={
              if @selected_cluster == cluster["id"],
                do: "font-semibold text-white",
                else: "text-gray-300 hover:text-white"
            }>
              {cluster["name"]}
            </span>
          </button>
        <% end %>
        <%= if @selected_cluster do %>
          <button
            phx-click="clear_highlights"
            class="text-[10px] text-amber-300 hover:text-amber-200 ml-1 uppercase tracking-wider"
          >
            clear
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  attr :stats, :map, required: true

  def intro(assigns) do
    ~H"""
    <div id="mood-intro" phx-hook="MoodIntroGate">
      <header class="mb-16 max-w-2xl">
        <h1 class="text-3xl font-bold tracking-tight">My Mood Journal</h1>
        <p class="text-gray-500 mt-2 mb-10">
          {@stats.entry_count} days, and counting.
        </p>

        <p class="text-sm text-gray-300 mb-5 leading-relaxed">
          I have bipolar disorder. The cartoon version is two poles, manic and depressed, and most of my days are weather somewhere between them. The clinical picture is more detailed; not by much. Mostly the days show up as some mix, and two words can't hold that. (I'm also lefthanded and colorblind, neither of which is relevant here, but you may as well know what kind of person you're following around.)
        </p>
        <p class="text-sm text-gray-300 mb-5 leading-relaxed">
          Anyway. My doctor put me on a mood chart. Five numbers a night; how the day went. I did it because I was told to, and I kept doing it long enough that it turned into a dataset. A few hundred days in, there was enough to ask what
          <em>the data</em>
          thought my states were, instead of what a diagnostic manual said they should be. The algorithm I ended up using lets a day belong
          <em>partly</em>
          to more than one state. Closer to how the days actually arrive.
        </p>
        <p class="text-sm text-gray-300 leading-relaxed">
          If "fuzzy clustering" doesn't mean anything yet, drag the dot below.
        </p>
      </header>

      <section class="mb-20">
        <h2 class="text-sm font-semibold uppercase tracking-widest text-gray-200 mb-4">
          Try it first
        </h2>
        <p class="text-sm text-gray-400 mb-6 leading-relaxed">
          Three fake clusters on an axis with no units. Drag the dot; drag the sliders. The bar shows how much the dot belongs to each cluster. Crank fuzziness all the way up and it belongs to
          <em>all</em>
          of them at once. There's a
          <a href="/menagerie" class="underline decoration-dotted hover:text-gray-200">
            bigger menagerie
          </a>
          if you want to reshape the membership curves themselves.
        </p>

        <div
          id="mood-tour-sandbox"
          phx-hook="MoodTourSandbox"
          phx-update="ignore"
          class="bg-base-200 rounded-lg p-6"
        >
        </div>

        <div class="flex justify-between items-center mt-8">
          <button
            type="button"
            data-skip-intro
            class="text-xs uppercase tracking-widest text-gray-600 cursor-pointer hover:text-gray-400 transition-colors"
          >
            Skip intro
          </button>
          <button
            type="button"
            data-start-tour
            class="text-xs uppercase tracking-widest text-gray-300 cursor-pointer hover:text-white transition-colors"
          >
            Show me around &rsaquo;
          </button>
        </div>
      </section>
    </div>
    """
  end

  attr :stats, :map, required: true
  attr :analysis, :map, required: true
  attr :selected_cluster, :any, default: nil
  attr :radar_centroids, :list, default: []
  attr :radar_dimensions, :list, default: []
  attr :ambiguity_bins, :list, default: []
  attr :ambiguity_threshold, :float, default: 0.45

  def chapter_states(assigns) do
    ~H"""
    <section id="mood-chapter-1" class="mb-20">
      <button
        type="button"
        id="mood-show-intro"
        data-show-intro
        class="text-xs uppercase tracking-widest text-gray-600 cursor-pointer hover:text-gray-400 transition-colors mb-3 inline-block"
        style="display:none"
      >
        &lsaquo; Show intro
      </button>
      <h2 class="text-base font-semibold uppercase tracking-widest text-gray-100 mb-6 flex items-baseline gap-3">
        <span class="text-xs text-gray-500 font-normal tracking-wider">01</span>
        <span>My mood states</span>
      </h2>

      <p class="text-sm text-gray-400 mb-4 leading-relaxed">
        Same idea, four years of real days behind it. The clustering found the categories; I named them once I could see them. The algorithm doesn't know anything about bipolar. It just notices when days resemble other days. Some of the names took a while to settle. A couple are still on probation.
        <.link
          navigate="/menagerie"
          class="text-amber-300 hover:text-amber-200 underline decoration-dotted underline-offset-4"
        >
          Play with the knobs yourself &rsaquo;
        </.link>
      </p>

      <p class="text-sm text-gray-400 mb-4 leading-relaxed">
        Run those {@stats.entry_count} days through fuzzy c-means and my moods land in {@stats.cluster_count} rough shapes, loose enough that a day can lean partly into more than one.
      </p>

      <p class="text-sm text-gray-400 mb-6 leading-relaxed">
        <%= if @stats.most_common do %>
          The one I live in most is <span style={"color: #{Map.get(@analysis.cluster_colors, @stats.most_common.id, "#aaa")}"}>
            {@stats.most_common.name}
          </span>: {@stats.most_common.days} days, about {div(
            @stats.most_common.days * 100,
            max(@stats.entry_count, 1)
          )}% of everything tracked.
        <% end %>
        <%= if @stats.longest_run do %>
          My longest uninterrupted stretch was {@stats.longest_run.days} days of <span style={"color: #{Map.get(@analysis.cluster_colors, @stats.longest_run.id, "#aaa")}"}>
            {@stats.longest_run.name}</span>.
        <% end %>
        Click any state to dim everything else; click again to let it back in.
      </p>

      <div class="text-[10px] uppercase tracking-widest text-amber-300/80 mb-1.5">
        ↓ click a state to isolate it
      </div>
      <div class="flex flex-wrap items-center gap-2">
        <%= for cluster <- @analysis.clusters do %>
          <button
            phx-click="cluster_selected"
            phx-value-cluster={cluster["id"]}
            class={"inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium cursor-pointer border-2 transition-all #{if @selected_cluster == cluster["id"], do: "ring-2 ring-amber-300 ring-offset-2 ring-offset-base-300 scale-110 shadow-lg", else: "hover:scale-105 hover:brightness-125"}"}
            style={"background: #{Map.get(@analysis.cluster_colors, cluster["id"], "#666")}#{if @selected_cluster == cluster["id"], do: "aa", else: "38"}; color: #{if @selected_cluster == cluster["id"], do: "#fff", else: Map.get(@analysis.cluster_colors, cluster["id"], "#aaa")}; border-color: #{Map.get(@analysis.cluster_colors, cluster["id"], "#666")}#{if @selected_cluster == cluster["id"], do: "", else: "88"}; #{if @selected_cluster && @selected_cluster != cluster["id"], do: "opacity:0.25", else: ""}"}
          >
            <span
              class="inline-block w-2 h-2 rounded-full"
              style={"background: #{Map.get(@analysis.cluster_colors, cluster["id"], "#666")}"}
            >
            </span>
            {cluster["name"]}
          </button>
        <% end %>
        <%= if @selected_cluster do %>
          <button
            phx-click="clear_highlights"
            class="text-xs text-amber-300 hover:text-amber-200 ml-1 font-medium"
          >
            &times; clear
          </button>
        <% end %>
      </div>
      <%= if @selected_cluster do %>
        <div class="text-xs text-gray-400 mt-2">
          Isolating <span
            class="font-semibold"
            style={"color: #{Map.get(@analysis.cluster_colors, @selected_cluster, "#aaa")}"}
          >
            {Enum.find_value(@analysis.clusters, fn c ->
              c["id"] == @selected_cluster && c["name"]
            end)}
          </span>; everything else across the page is dimmed.
        </div>
      <% end %>

      <div class="bg-base-200 rounded-lg p-4 mt-4" style="min-height: 180px;">
        <ClusterRadar.radars
          centroids={@radar_centroids}
          dimensions={@radar_dimensions}
          cluster_colors={@analysis.cluster_colors}
          selected_cluster={@selected_cluster}
        />
      </div>

      <p class="text-sm text-gray-400 leading-relaxed mt-6 mb-4">
        Those are the shapes. Some days <em>didn't</em>
        commit to any of them: {@stats.ambiguity.count} ({@stats.ambiguity.pct}%), with no single state owning more than 45%. A hard clustering model would shove each one into a box. Fuzzy doesn't have to.
      </p>

      <div class="bg-base-200 rounded-lg p-4 mt-4">
        <h3 class="text-sm font-semibold text-gray-200 mb-2">Days in-between</h3>
        <AmbiguityHistogram.histogram bins={@ambiguity_bins} threshold={@ambiguity_threshold} />
      </div>
    </section>
    """
  end

  attr :stats, :map, required: true
  attr :analysis, :map, required: true
  attr :date_range, :any, default: nil
  attr :highlighted_dates, :list, default: []
  attr :selected_gap, :any, default: nil
  attr :selected_cluster, :any, default: nil
  attr :selected_day, :any, default: nil
  attr :calendar_days, :list, default: []
  attr :transition_dates, :list, default: []
  attr :stream_series, :list, default: []
  attr :season_months, :list, default: []

  def chapter_day_by_day(assigns) do
    ~H"""
    <section id="mood-chapter-2" class="mb-20">
      <h2 class="text-base font-semibold uppercase tracking-widest text-gray-100 mb-6 flex items-baseline gap-3">
        <span class="text-xs text-gray-500 font-normal tracking-wider">02</span>
        <span>Day by day</span>
      </h2>
      <p class="text-sm text-gray-400 mb-4 leading-relaxed">
        Lived through, four years of mood is just <em>now</em>, over and over; you can't feel a season of yourself while you're in it. From outside it's something else. Stripes, runs, pockets where one state pooled for weeks before something tipped.
      </p>
      <p class="text-sm text-gray-400 mb-6 leading-relaxed">
        Every square is a day. Color is the dominant state; brightness is how hard it pulled. White borders mark days where the dominant state changed and stayed changed; wobbles don't count.
        <%= if @stats.first_state && @stats.last_state do %>
          I started in
          <span style={"color: #{Map.get(@analysis.cluster_colors, @stats.first_state.id, "#aaa")}"}>
            {@stats.first_state.name}
          </span>
          and, for now, I'm in <span style={"color: #{Map.get(@analysis.cluster_colors, @stats.last_state.id, "#aaa")}"}>
            {@stats.last_state.name}</span>.
        <% end %>
        Drag across the strip below to zoom into a window, or click any square to see the days around it.
      </p>

      <div>
        <div
          id="temporal-brush"
          phx-hook="TemporalBrush"
          phx-update="ignore"
          style="min-height: 50px;"
        >
        </div>
        <%= if @date_range do %>
          <div class="flex items-center gap-2 mt-1">
            <span class="text-xs text-gray-500">
              {elem(@date_range, 0)} → {elem(@date_range, 1)}
            </span>
            <button
              phx-click="brush_changed"
              phx-value-start=""
              phx-value-end=""
              class="text-xs text-gray-500 hover:text-gray-300"
            >
              clear
            </button>
          </div>
        <% end %>
      </div>

      <div class="mt-3">
        <CalendarGrid.card
          days={@calendar_days}
          cluster_colors={@analysis.cluster_colors}
          cluster_names={@analysis.cluster_names}
          transition_dates={@transition_dates}
          highlighted_dates={@highlighted_dates}
          selected_gap={@selected_gap}
          selected_cluster={@selected_cluster}
        />
      </div>

      <p class="text-sm text-gray-400 leading-relaxed mt-6 mb-4">
        Same days, sideways. Above, one square per day. Below, each band is one state's share of the week across the four years, smoothed.
      </p>

      <div class="bg-base-200 rounded-lg p-4 mt-4">
        <h3 class="text-sm font-semibold text-gray-200 mb-2">How my states ebb and flow</h3>
        <StreamGraph.stream
          series={@stream_series}
          cluster_ids={@analysis.cluster_ids}
          cluster_colors={@analysis.cluster_colors}
          cluster_names={@analysis.cluster_names}
          selected_cluster={@selected_cluster}
          selected_day={@selected_day}
        />
      </div>

      <div class="mt-8">
        <h3 class="text-sm font-semibold text-gray-200 mb-2">Same months, every year</h3>
        <p class="text-xs text-gray-500 mb-3">
          The stream above shows what happened; this one collapses it across years to ask whether anything <em>repeats</em>. Each wedge is a calendar month (January at twelve o'clock, clockwise through December), pooled across every year tracked. If there's an annual rhythm, certain months will lean the same color year over year.
        </p>
        <SeasonRing.ring
          months={@season_months}
          cluster_ids={@analysis.cluster_ids}
          cluster_names={@analysis.cluster_names}
          cluster_colors={@analysis.cluster_colors}
          selected_cluster={@selected_cluster}
        />
      </div>
    </section>
    """
  end

  attr :stats, :map, required: true
  attr :analysis, :map, required: true
  attr :mood_transitions, :list, default: []
  attr :selected_cluster, :any, default: nil
  attr :highlighted_dates, :list, default: []
  attr :cluster_names, :map, required: true
  attr :timeline_segments, :list, default: []

  def chapter_shifts(assigns) do
    ~H"""
    <section id="mood-chapter-3" class="mb-20">
      <h2 class="text-base font-semibold uppercase tracking-widest text-gray-100 mb-6 flex items-baseline gap-3">
        <span class="text-xs text-gray-500 font-normal tracking-wider">03</span>
        <span>How my moods shift</span>
      </h2>
      <p class="text-sm text-gray-400 mb-4 leading-relaxed">
        The transitions carry more than the states do. Some hand-offs are well-worn paths; others basically never happen. Knowing the state I'm in tells you less than knowing the one I just left. From the inside, most of bipolar is the moving around; the states are just where the motion idles.
      </p>
      <p class="text-sm text-gray-400 mb-6 leading-relaxed">
        The dominant state flipped {@stats.transition_count} times across {@stats.entry_count} days, about once every {div(
          @stats.entry_count,
          max(@stats.transition_count, 1)
        )} days. I only count a flip when the new state holds for at least five days; anything shorter is noise.
        <%= if @stats.biggest_flow && @stats.biggest_flow.from && @stats.biggest_flow.to do %>
          The most-worn path was
          <span style={"color: #{Map.get(@analysis.cluster_colors, @stats.biggest_flow.from.id, "#aaa")}"}>
            {@stats.biggest_flow.from.name}
          </span>
          →
          <span style={"color: #{Map.get(@analysis.cluster_colors, @stats.biggest_flow.to.id, "#aaa")}"}>
            {@stats.biggest_flow.to.name}
          </span>
          ({@stats.biggest_flow.count}×).
        <% end %>
        Each run of a state is one block below; white marks the hand-offs.
      </p>

      <div class="bg-base-200 rounded-lg p-4">
        <TransitionTimeline.timeline
          segments={@timeline_segments}
          transitions={@mood_transitions}
          cluster_colors={@analysis.cluster_colors}
          selected_cluster={@selected_cluster}
        />
      </div>

      <p class="text-sm text-gray-400 leading-relaxed mt-6 mb-4">
        Above: which transitions happened, when.<br />
        Below: which ones tend to happen <em>at all</em>, summed across the four years: the well-worn paths next to the ones that almost never light up.
      </p>

      <div class="bg-base-200 rounded-lg p-4 mt-4">
        <h3 class="text-sm font-semibold text-gray-200 mb-2">Where do I go from here?</h3>
        <p class="text-xs text-gray-500 mb-3">
          Once I'm in a state, where does it usually go next? Thicker bands are the well-worn paths.
        </p>
        <TransitionSankey.sankey
          transitions={@mood_transitions}
          cluster_ids={@analysis.cluster_ids}
          cluster_names={@analysis.cluster_names}
          cluster_colors={@analysis.cluster_colors}
          selected_cluster={@selected_cluster}
        />
      </div>

      <p class="text-sm text-gray-400 leading-relaxed mt-6 mb-4">
        The next two panels are the same thing in other keys. One's a vibe (a chaotic-but-bounded attractor that happens to behave like the data). The other is the list of transitions, each one a date and a hand-off.
      </p>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mt-4 items-stretch">
        <div class="bg-base-200 rounded-lg p-4 flex flex-col h-full">
          <h3 class="text-sm font-semibold text-gray-200 mb-2">Phase space, without the diary</h3>
          <p class="text-sm text-gray-300 mb-3 leading-relaxed">
            A Thomas attractor in the palette above; three coupled equations looping a bounded region forever, never quite repeating. States as gravity wells, with the path never settling into any of them. The math doesn't know it's a metaphor.
          </p>
          <div
            id="cluster-attractor"
            phx-hook="ClusterAttractor"
            phx-update="ignore"
            class="flex-1 min-h-0"
            data-colors={Jason.encode!(Map.values(@analysis.cluster_colors))}
          >
          </div>
        </div>

        <.live_component
          module={MoodTransitions}
          id="mood-transitions-list"
          transitions={@mood_transitions}
          cluster_colors={@analysis.cluster_colors}
          cluster_names={@cluster_names}
          selected_cluster={@selected_cluster}
          highlighted_dates={@highlighted_dates}
        />
      </div>
    </section>
    """
  end

  attr :stats, :map, required: true
  attr :drift_dimensions, :list, default: []
  attr :analysis, :map, required: true
  attr :mood_flowers_list, :list, default: []
  attr :flower_dimensions, :list, default: []
  attr :selected_day, :any, default: nil
  attr :distribution_points, :list, default: []
  attr :distribution_clusters, :list, default: []

  def chapter_under_hood(assigns) do
    ~H"""
    <section id="mood-chapter-4" class="mb-20">
      <h2 class="text-base font-semibold uppercase tracking-widest text-gray-100 mb-6 flex items-baseline gap-3">
        <span class="text-xs text-gray-500 font-normal tracking-wider">04</span>
        <span>Under the hood</span>
      </h2>
      <p class="text-sm text-gray-400 mb-4 leading-relaxed">
        So far you've been seeing the <em>output</em>
        of the model: the named states, how they ebb, how they hand off. This section is the <em>input</em>. Five numbers a night, before anything else happens to them. Sleep, anxiety, sensitivity, outlook, speed; each on its own scale. The whole picture above is built out of that one habit.
      </p>
      <p class="text-sm text-gray-400 mb-6 leading-relaxed">
        The clustering doesn't see anything else about me; every shape further up the page is downstream of these five. Here's what they each do on their own: how they drift across {@stats.entry_count} days; how the distributions shift once the model splits the days into states. Some of it I expected. The rest is why the model was worth the trouble.
      </p>

      <div class="bg-base-200 rounded-lg p-4">
        <h3 class="text-sm font-semibold text-gray-200 mb-2">A flower for every month</h3>
        <p class="text-xs text-gray-500 mb-3">
          Each flower is one month. Spokes are the average of the five raw inputs over that month; long means high, short means low. The fill color is whichever cluster ran the month, once the numbers went through the model. Inputs and output, side by side.
        </p>
        <MoodFlowers.flowers
          flowers={@mood_flowers_list}
          dimensions={@flower_dimensions}
          cluster_colors={@analysis.cluster_colors}
          cluster_names={@analysis.cluster_names}
          selected_day={@selected_day}
        />
      </div>

      <p class="text-sm text-gray-400 leading-relaxed mt-6 mb-4">
        Flowers above are each month, snapshotted. The next chart is the same five inputs, but as lines, a 90-day rolling average that asks whether any of them slowly drifted while I wasn't paying attention.
      </p>

      <div class="mt-8">
        <h3 class="text-sm font-semibold text-gray-200 mb-2">Has anything drifted?</h3>
        <p class="text-xs text-gray-500 mb-3">
          A 90-day rolling average for each of the five raw inputs. If a line tilts, my baseline shifted. Slow changes like that are basically invisible while you're in them.
        </p>
        <DimensionDrift.drift dimensions={@drift_dimensions} />
      </div>

      <p class="text-sm text-gray-400 leading-relaxed mt-6 mb-4">
        Drift above asks whether the baseline shifted. The next chart asks something different: whether the inputs themselves look the same depending on which state was running, whether "sleep" means the same number on a manic day as on a depressive one.
      </p>

      <div class="mt-8">
        <h3 class="text-sm font-semibold text-gray-200 mb-2">Distributions, by state</h3>
        <p class="text-xs text-gray-500 mb-3">
          For each input: where it usually lands <em>overall</em>
          (the dashed outline) versus where it lands inside each cluster (the filled shapes). Each row has its own scale; the inputs aren't on the same range. A dimension whose shape barely shifts between states isn't pulling much weight in the model.
        </p>
        <DimensionDistributions.distributions
          points={@distribution_points}
          dimensions={@flower_dimensions}
          clusters={@distribution_clusters}
        />
      </div>
    </section>
    """
  end

  attr :stats, :map, required: true
  attr :analysis, :map, required: true
  attr :cluster_names, :map, required: true
  attr :gap_transitions, :list, default: []
  attr :imputed_memberships, :map, default: %{}
  attr :full_date_range, :any, default: nil

  def chapter_gaps(assigns) do
    ~H"""
    <section id="mood-chapter-5" class="mb-20">
      <h2 class="text-base font-semibold uppercase tracking-widest text-gray-100 mb-6 flex items-baseline gap-3">
        <span class="text-xs text-gray-500 font-normal tracking-wider">05</span>
        <span>The gaps</span>
      </h2>
      <p class="text-sm text-gray-400 mb-4 leading-relaxed">
        The days I didn't track are also data. Tracking is the first thing to fall off when a state gets loud; when the form goes quiet, it's rarely because nothing was happening.
      </p>
      <p class="text-sm text-gray-400 mb-6 leading-relaxed">
        <%= if @stats.gap_count > 0 do %>
          I miss days. There are {@stats.gap_count} stretches where I went quiet; most of the time the state I came back in wasn't the state I left. That asymmetry was its own surprise. Click a state above to see which gaps touched it.
        <% else %>
          No gaps; every day in the window is accounted for.
        <% end %>
      </p>

      <.live_component
        module={GapAnalysis}
        id="gaps"
        gap_transitions={@gap_transitions}
        imputed_memberships={@imputed_memberships}
        date_range={@full_date_range}
        cluster_colors={@analysis.cluster_colors}
        cluster_names={@cluster_names}
      />
    </section>
    """
  end

  def toc(assigns) do
    ~H"""
    <nav class="my-16 max-w-xl mx-auto" aria-label="Chapter navigation">
      <div class="text-[10px] uppercase tracking-widest text-gray-500 mb-3">In this chapter</div>
      <ol class="text-sm text-gray-300 space-y-2">
        <li>
          <a href="#mood-chapter-1" class="hover:text-amber-300 transition-colors">
            <span class="text-xs text-gray-500 mr-2">01</span>My mood states
          </a>
        </li>
        <li>
          <a href="#mood-chapter-2" class="hover:text-amber-300 transition-colors">
            <span class="text-xs text-gray-500 mr-2">02</span>Day by day
          </a>
        </li>
        <li>
          <a href="#mood-chapter-3" class="hover:text-amber-300 transition-colors">
            <span class="text-xs text-gray-500 mr-2">03</span>How my moods shift
          </a>
        </li>
        <li>
          <a href="#mood-chapter-4" class="hover:text-amber-300 transition-colors">
            <span class="text-xs text-gray-500 mr-2">04</span>Under the hood
          </a>
        </li>
        <li>
          <a href="#mood-chapter-5" class="hover:text-amber-300 transition-colors">
            <span class="text-xs text-gray-500 mr-2">05</span>The gaps
          </a>
        </li>
      </ol>
    </nav>
    """
  end

  def interstitial_after_states(assigns) do
    ~H"""
    <aside class="my-8 max-w-xl mx-auto">
      <p class="text-sm text-gray-300 leading-relaxed">
        Quick pause. The shapes by themselves are just buckets: bins the days fell into, with names I made up once I could see them. You can bin anything. What the bins do once you put them back in chronological order is where it gets weird.
      </p>
    </aside>
    """
  end

  def interstitial_before_gaps(assigns) do
    ~H"""
    <aside class="my-8 max-w-xl ml-auto">
      <p class="text-sm text-gray-300 leading-relaxed">
        One more thing before I close out. Every chart up to this one has been built from days I sat down and filled out the form. The next part is about the days I didn't.
      </p>
    </aside>
    """
  end

  def afterword(assigns) do
    ~H"""
    <section class="mb-16 max-w-2xl">
      <h2 class="text-base font-semibold uppercase tracking-widest text-gray-100 mb-6">After</h2>
      <p class="text-sm text-gray-300 mb-5 leading-relaxed">
        A four-year snapshot, and no promise of a fifth. Resolution this fine wasn't the goal; it's just what fell out of doing the chart every night.
      </p>
      <p class="text-sm text-gray-300 mb-5 leading-relaxed">
        None of this is a recommendation, or a method, or a diagnosis. Just higher resolution than two words allow, on the question of what bipolar is doing inside one specific head over four years. The numbers sit alongside the words, and once in a while they catch something the words miss.
      </p>
      <p class="text-sm text-gray-300 leading-relaxed">
        If you read this far, thanks. If anything landed, or you've made something like this from your own data, I'd like to hear about it.
      </p>
    </section>
    """
  end
end
