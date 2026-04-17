defmodule FugueWeb.MoodLive.Sections do
  @moduledoc """
  Function components for each chapter of the /mood page. The LiveView module
  (`FugueWeb.MoodLive`) owns state, push_event payloads, and handle_event
  callbacks; this module owns the markup so render/1 there stays short and the
  chapters are individually readable.
  """

  use Phoenix.Component

  alias FugueWeb.MoodLive.{Calendar, GapAnalysis, MoodTransitions}

  attr :stats, :map, required: true

  def hero(assigns) do
    ~H"""
    <section class="mb-20 -mx-4 md:-mx-8">
      <div class="bg-black/40 border-y border-white/5 py-10 px-4 md:px-8">
        <div class="max-w-5xl mx-auto">
          <div
            id="mood-trajectory"
            phx-hook="MoodTrajectory"
            phx-update="ignore"
            class="w-full"
            style="min-height: 520px;"
          >
          </div>

          <div class="mt-8 max-w-xl ml-auto border-t border-white/10 pt-5 text-[11px] leading-relaxed text-gray-400 font-serif">
            <div class="uppercase tracking-[0.2em] text-[10px] text-gray-500 mb-1">
              Wall text
            </div>
            <div class="text-gray-200 text-sm mb-1 italic">
              Four Years, One Line
            </div>
            <div class="text-gray-500 mb-3">
              {@stats.date_range && elem(@stats.date_range, 0)} – {@stats.date_range &&
                elem(@stats.date_range, 1)} &middot; PCA projection on daily self-ratings &middot; real limoges
            </div>
            <p class="mb-2">
              Every evening before bed for the past four years I wrote down five numbers about how I was doing. This is all of them, squashed onto a flat plane by a little math that tries to preserve the shape of the whole thing while throwing the rest away.
            </p>
            <p>
              One dot per day. The line is the order I lived them in — start to wherever I am now. The colors are the mood states the clustering found later, painted back onto the path after the fact. I didn't pick where any of it went, and watching it loop back through the same regions never gets old.
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
          I have bipolar disorder. The cartoon version is two poles — manic, depressed — but the inside of it is way more interesting than that. Most days aren't either. Most days are <em>something</em>, and that something is too textured to name with two words.
        </p>
        <p class="text-sm text-gray-300 mb-5 leading-relaxed">
          The language I was handed didn't have enough resolution for what I was actually experiencing, so I started writing down numbers instead. A handful, every night, about how the day had felt. After a few hundred days I had enough to ask the data what
          <em>it</em>
          thought my states were, instead of what a diagnostic manual said they should be. I ran it through an algorithm that lets a day belong
          <em>partly</em>
          to more than one state instead of forcing it into one — because that's how the days actually arrive.
        </p>
        <p class="text-sm text-gray-300 leading-relaxed">
          If "fuzzy clustering" doesn't click yet, that's okay — drag the dot below and watch what happens.
        </p>
      </header>

      <section class="mb-20">
        <h2 class="text-sm font-semibold uppercase tracking-widest text-gray-200 mb-4">
          Try it first
        </h2>
        <p class="text-sm text-gray-400 mb-6 max-w-2xl leading-relaxed">
          Three fake clusters on an axis with no units. Drag the dot. Drag the sliders. The bar shows how much the dot belongs to each cluster — at high fuzziness it belongs to
          <em>all</em>
          of them, a little. If you want more than a toy, there's a
          <a href="/menagerie" class="underline decoration-dotted hover:text-gray-200">
            bigger menagerie
          </a>
          where you can reshape the membership curves themselves.
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

  def chapter_states(assigns) do
    ~H"""
    <section id="mood-chapter-1" class="mb-24">
      <button
        type="button"
        id="mood-show-intro"
        data-show-intro
        class="text-xs uppercase tracking-widest text-gray-600 cursor-pointer hover:text-gray-400 transition-colors mb-3 inline-block"
        style="display:none"
      >
        &lsaquo; Show intro
      </button>
      <h2 class="text-sm font-semibold uppercase tracking-widest text-gray-200 mb-4">
        My mood states
      </h2>

      <p class="text-sm text-gray-400 mb-4 leading-relaxed">
        Same idea as the toy above, now with four years of real days behind it. These aren't categories I picked off a list — they're shapes the data found on its own, and I named them once I could see what they looked like. The clustering doesn't care about diagnostic labels; it just notices when days look like other days. Naming them after the fact felt like meeting parts of myself I'd been living with but never introduced.
        <.link
          navigate="/menagerie"
          class="text-amber-300 hover:text-amber-200 underline decoration-dotted underline-offset-4"
        >
          Play with the knobs yourself &rsaquo;
        </.link>
      </p>

      <p class="text-sm text-gray-400 mb-6 leading-relaxed">
        Run {@stats.entry_count} days through fuzzy c-means clustering and my moods fall into {@stats.cluster_count} rough shapes — not boxes, more like gravity wells a day can lean toward.
        <%= if @stats.most_common do %>
          The one I live in most is
          <span style={"color: #{Map.get(@analysis.cluster_colors, @stats.most_common.id, "#aaa")}"}>
            {@stats.most_common.name}
          </span>
          — {@stats.most_common.days} days, about {div(
            @stats.most_common.days * 100,
            max(@stats.entry_count, 1)
          )}% of everything tracked.
        <% end %>
        <%= if @stats.longest_run do %>
          My longest uninterrupted stretch was {@stats.longest_run.days} days of <span style={"color: #{Map.get(@analysis.cluster_colors, @stats.longest_run.id, "#aaa")}"}>
            {@stats.longest_run.name}</span>.
        <% end %>
        Click any state to dim everything else across the page — click it again to let everything back in.
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
          Isolating
          <span
            class="font-semibold"
            style={"color: #{Map.get(@analysis.cluster_colors, @selected_cluster, "#aaa")}"}
          >
            {Enum.find_value(@analysis.clusters, fn c ->
              c["id"] == @selected_cluster && c["name"]
            end)}
          </span>
          — everything else across the page is dimmed.
        </div>
      <% end %>

      <div class="bg-base-200 rounded-lg p-4 mt-4">
        <div
          id="cluster-radar"
          phx-hook="ClusterRadar"
          phx-update="ignore"
          style="min-height: 180px;"
        >
        </div>
      </div>

      <div class="bg-base-200 rounded-lg p-4 mt-4">
        <h3 class="text-sm font-semibold text-gray-400 mb-2">Days in-between</h3>
        <p class="text-xs text-gray-500 mb-3 max-w-3xl">
          Most days lean clearly toward one state. But {@stats.ambiguity.count} days ({@stats.ambiguity.pct}%) refused to settle — no single state owned more than 45% of the day. These are the entries where fuzzy clustering earns its keep: a hard model would force each into a box, but these days genuinely lived between states.
        </p>
        <div
          id="ambiguity-histogram"
          phx-hook="AmbiguityHistogram"
          phx-update="ignore"
          style="min-height: 140px;"
        >
        </div>
      </div>
    </section>
    """
  end

  attr :stats, :map, required: true
  attr :analysis, :map, required: true
  attr :date_range, :any, default: nil
  attr :highlighted_dates, :list, default: []
  attr :selected_gap, :any, default: nil

  def chapter_day_by_day(assigns) do
    ~H"""
    <section id="mood-chapter-2" class="mb-24">
      <h2 class="text-sm font-semibold uppercase tracking-widest text-gray-200 mb-4">
        Day by day
      </h2>
      <p class="text-sm text-gray-400 mb-4 leading-relaxed">
        From the inside, four years of mood is just <em>now</em>, over and over — you can't feel a season of yourself while you're in it. Pulling back this far is its own pleasure: stripes, runs, pockets where one state pooled for weeks before something tipped it over. I can point to whole stretches and say <em>oh, right, that's where I was</em>, and the recognition is fun every time.
      </p>
      <p class="text-sm text-gray-400 mb-6 leading-relaxed">
        Every square is a day. Color is the dominant mood state; brightness is how hard it pulled. White-bordered squares are the days when the dominant state actually changed — the meaningful hand-offs, not the day-to-day jitter.
        <%= if @stats.first_state && @stats.last_state do %>
          I started in
          <span style={"color: #{Map.get(@analysis.cluster_colors, @stats.first_state.id, "#aaa")}"}>
            {@stats.first_state.name}
          </span>
          and — for now — I'm in <span style={"color: #{Map.get(@analysis.cluster_colors, @stats.last_state.id, "#aaa")}"}>
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
        <.live_component
          module={Calendar}
          id="calendar"
          highlighted_dates={@highlighted_dates}
          selected_gap={@selected_gap}
        />
      </div>

      <div class="bg-base-200 rounded-lg p-4 mt-4">
        <h3 class="text-sm font-semibold text-gray-400 mb-2">How my states ebb and flow</h3>
        <div
          id="cluster-stream"
          phx-hook="ClusterStream"
          phx-update="ignore"
          style="min-height: 210px;"
        >
        </div>
      </div>

      <div class="bg-base-200 rounded-lg p-4 mt-4">
        <h3 class="text-sm font-semibold text-gray-400 mb-2">Same months, every year</h3>
        <p class="text-xs text-gray-500 mb-3 max-w-3xl">
          The stream above shows what happened; this collapses it across years to ask whether it <em>repeats</em>. Each wedge is a calendar month — January at twelve o'clock, clockwise through December. The fill shows how days split across states for that month, pooled over every year tracked. If there's an annual rhythm, certain months will consistently lean toward one color.
        </p>
        <div
          id="season-ring"
          phx-hook="SeasonRing"
          phx-update="ignore"
          style="min-height: 420px;"
        >
        </div>
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

  def chapter_shifts(assigns) do
    ~H"""
    <section id="mood-chapter-3" class="mb-24">
      <h2 class="text-sm font-semibold uppercase tracking-widest text-gray-200 mb-4">
        How my moods shift
      </h2>
      <p class="text-sm text-gray-400 mb-4 leading-relaxed">
        The interesting question isn't which state I'm in — it's the verbs. The hand-offs. What does a day tend to
        <em>become</em>
        the next morning? Some pairs are well-worn paths and some almost never happen, and the shape of those preferences says something about me I couldn't have named on my own. The motion is what bipolar actually is, from the inside; the states are just where the motion pauses to catch its breath.
      </p>
      <p class="text-sm text-gray-400 mb-6 leading-relaxed">
        The dominant state flipped {@stats.transition_count} times across {@stats.entry_count} days — roughly once every {div(
          @stats.entry_count,
          max(@stats.transition_count, 1)
        )} days on average. I'm only counting a hand-off when the new state holds for at least five days; anything shorter is the model arguing with itself, not me actually moving.
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
        The timeline below turns every reign of a mood state into a colored block, with white markers at every handoff.
      </p>

      <div class="bg-base-200 rounded-lg p-4">
        <div
          id="transition-timeline"
          phx-hook="TransitionTimeline"
          phx-update="ignore"
          style="min-height: 50px;"
        >
        </div>
      </div>

      <div class="bg-base-200 rounded-lg p-4 mt-4">
        <h3 class="text-sm font-semibold text-gray-400 mb-2">Where do I go from here?</h3>
        <p class="text-xs text-gray-500 mb-3">
          Once I'm in a state, where does it tend to drop me next? Thicker bands mean a well-trodden path.
        </p>
        <div
          id="transition-sankey"
          phx-hook="TransitionSankey"
          phx-update="ignore"
          style="min-height: 320px;"
        >
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mt-4 items-stretch">
        <div class="bg-base-200 rounded-lg p-4 flex flex-col h-full">
          <h3 class="text-sm font-semibold text-gray-200 mb-1">Phase space, without the diary</h3>
          <p class="text-xs text-gray-500 mb-3 leading-snug">
            A Thomas strange attractor in the palette above. Three coupled equations looping a bounded region forever without repeating — states as gravity wells, living as a path that can't quite settle into any of them.
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

  def chapter_under_hood(assigns) do
    ~H"""
    <section id="mood-chapter-4" class="mb-24">
      <h2 class="text-sm font-semibold uppercase tracking-widest text-gray-200 mb-4">
        Under the hood
      </h2>
      <p class="text-sm text-gray-400 mb-4 leading-relaxed">
        Up to here it's been the <em>output</em>
        of the model — the named states, how they ebb, how they hand off. This section is the <em>input</em>: the five numbers I jot down every night before bed, before anything fancy happens to them. Sleep, anxiety, sensitivity, outlook, and speed, each on 0–10. The whole picture above is built out of that one tiny daily habit.
      </p>
      <p class="text-sm text-gray-400 mb-6 leading-relaxed">
        They're the only thing the clustering knows about me — every shape further up the page is downstream of them. Here's what the five actually do on their own: how they drift over time across all {@stats.entry_count} days, and how their shape shifts once the model splits the days into states. Some of it I expected. A couple of dimensions genuinely surprised me, and that's been my favorite part of doing this.
      </p>

      <div class="bg-base-200 rounded-lg p-4">
        <h3 class="text-sm font-semibold text-gray-400 mb-2">A flower for every month</h3>
        <p class="text-xs text-gray-500 mb-3">
          Each flower is one month. The shape is the average of those five raw inputs over the month — long spokes are dimensions that ran high, short ones ran low. The fill color is whichever cluster came out on top once the same numbers went through the model. Same data, two readings: the inputs you'd recognize and the output they add up to.
        </p>
        <div
          id="mood-flowers"
          phx-hook="MoodFlowers"
          phx-update="ignore"
          style="min-height: 460px;"
        >
        </div>
      </div>

      <div class="bg-base-200 rounded-lg p-4 mt-4">
        <h3 class="text-sm font-semibold text-gray-400 mb-2">Has anything drifted?</h3>
        <p class="text-xs text-gray-500 mb-3 max-w-3xl">
          A 90-day rolling average for each of the five raw inputs. If a line tilts over the years, my baseline for that dimension has shifted — the kind of slow change that's invisible from inside but shows up when you zoom out far enough.
        </p>
        <div
          id="dimension-drift"
          phx-hook="DimensionDrift"
          phx-update="ignore"
          style="min-height: 280px;"
        >
        </div>
      </div>

      <div class="bg-base-200 rounded-lg p-4 mt-4">
        <h3 class="text-sm font-semibold text-gray-400 mb-2">Distributions, by state</h3>
        <p class="text-xs text-gray-500 mb-3 max-w-3xl">
          For each of the five inputs: where it usually lands <em>overall</em>
          (the dashed outline), and where it lands once you split by cluster (the filled shapes). Each row uses its own scale because the five inputs aren't all rated on the same range. A dimension whose shape barely shifts between states is pulling less weight; a dimension whose shape slides across the range is doing a lot of the work.
        </p>
        <div
          id="dimension-distributions"
          phx-hook="DimensionDistributions"
          phx-update="ignore"
          style="min-height: 500px;"
        >
        </div>
      </div>
    </section>
    """
  end

  attr :stats, :map, required: true
  attr :gaps, :any, default: nil
  attr :analysis, :map, required: true
  attr :selected_cluster, :any, default: nil
  attr :cluster_names, :map, required: true

  def chapter_gaps(assigns) do
    ~H"""
    <section id="mood-chapter-5" class="mb-24">
      <h2 class="text-sm font-semibold uppercase tracking-widest text-gray-200 mb-4">The gaps</h2>
      <p class="text-sm text-gray-400 mb-4 leading-relaxed">
        The days I didn't track are also data. Tracking is the first thing to drop when a state gets loud enough to crowd out the form — so when the page goes quiet, it's almost never because nothing was happening. The gaps aren't holes in the record so much as a different kind of entry: <em>whatever this was, it was bigger than the form</em>.
      </p>
      <p class="text-sm text-gray-400 mb-6 leading-relaxed">
        <%= if @stats.gap_count > 0 do %>
          I'm not perfect at this — I missed some days. There are {@stats.gap_count} stretches where I went quiet, and a lot of the time the state I came back in wasn't the state I left in. The shape of
          <em>that</em>
          turned out to be its own interesting pattern. Click a mood state above to see which gaps touched it.
        <% else %>
          No gaps — every day in the window is accounted for.
        <% end %>
      </p>

      <.live_component
        module={GapAnalysis}
        id="gaps"
        gaps={@gaps}
        cluster_colors={@analysis.cluster_colors}
        cluster_names={@cluster_names}
        selected_cluster={@selected_cluster}
      />
    </section>
    """
  end

  def afterword(assigns) do
    ~H"""
    <section class="mb-16 max-w-2xl">
      <h2 class="text-sm font-semibold uppercase tracking-widest text-gray-200 mb-4">After</h2>
      <p class="text-sm text-gray-300 mb-5 leading-relaxed">
        That's the shape of it, for now. Tonight I'll write down five more numbers, and the picture will be a little different. Come back in a few months and it'll be different in ways neither of us can predict yet — that's part of the fun.
      </p>
      <p class="text-sm text-gray-300 mb-5 leading-relaxed">
        None of this is a recommendation, a method, or a diagnosis. It's just me looking at myself with a little more resolution than the language I was handed, because being bipolar is genuinely interesting from the inside and I wanted a way to share that. The numbers don't replace the words — they sit next to them, and sometimes they catch something the words miss.
      </p>
      <p class="text-sm text-gray-300 leading-relaxed">
        If you read this far, thank you. If something in here landed for you — or if you've built something like it for your own data — I'd genuinely like to hear about it.
      </p>
    </section>
    """
  end
end
