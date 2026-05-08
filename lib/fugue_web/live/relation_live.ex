defmodule FugueWeb.RelationLive do
  use FugueWeb, :live_view

  alias FugueWeb.RelationLive.Splashes

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Relational")
     |> assign(
       :meta_description,
       "A long walk down to the picture where things are placeholders for relations."
     )}
  end

  def render(assigns) do
    ~H"""
    <article class="px-4 py-8 max-w-3xl mx-auto">
      <header class="mb-12 max-w-2xl">
        <h1 class="text-3xl font-bold tracking-tight text-base-content">
          Relational.
        </h1>
        <p class="text-gray-500 mt-2 mb-6">
          The long one. Working title.
        </p>
        <aside class="font-mono text-xs text-base-content/55 leading-relaxed border-l-2 border-base-content/20 pl-3 not-italic">
          Heads up. This is the long one -- about 35 minutes if you read it,
          closer to fifty if you play with the splashes. Pack a snack. The
          door is open if you need to step out; the chapter resumes wherever
          you left off, because the chapter isn't really going anywhere.
        </aside>
      </header>

      <.section number="1" id="hook">
        <Splashes.gray_squares_splash />

        <p class="text-sm text-base-content/65 leading-relaxed">
          Two squares. Same gray, supposedly. Look at them -- they don't look
          the same. The one on the left reads as nearly white, the one on the
          right as nearly black. There's a way to verify: cover the
          surroundings with your finger and the gray collapses to one gray.
          Uncover, and it splits again.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed italic">
          If the gray was in the square, why does it change when nothing in
          the square changed?
        </p>
      </.section>

      <.section number="2" id="perception" title="Perception">
        <p class="text-sm text-base-content/65 leading-relaxed">
          Take the gray seriously. The gray wasn't in the square; it was in
          the relationship between the square and what surrounded it, the
          eye's running adaptation, the squares it had just seen, the word
          it had for "gray" at all. None of those are in the square. All of
          them changed.
        </p>

        <Splashes.perception_chain_splash />

        <p class="text-sm text-base-content/65 leading-relaxed">
          The screen runs on it. So does the dress. So does the
          checker-shadow demo. Every time you assumed a property was in the
          thing, it turned out to be in the relation. Drag the patch and
          watch the property move while nothing in the patch moves.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed italic">
          Fine. Perception is relational. Maybe perception is just a special case.
        </p>
      </.section>

      <.section number="3" id="systems" title="Systems">
        <p class="text-sm text-base-content/65 leading-relaxed">
          A flock isn't a bird plus a bird plus another bird. Watch one long
          enough and the agents stop mattering -- what you're tracking is
          alignment, separation, attraction, the pulls between birds rather
          than the birds themselves. Fade the birds out and the field is
          still there, humming.
        </p>

        <Splashes.fading_boid_splash />

        <p class="text-sm text-base-content/65 leading-relaxed">
          Two nodes look different. Hover them; their connections are
          identical. Same node, twice. Two nodes look identical and turn out
          to be wired into completely different worlds. Different nodes,
          same face. Same move outside perception. Same answer.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed italic">
          You can stop here. The argument is complete in everything we've
          shown. But there's one more place this pattern shows up, and it's
          the place that suggests it isn't a pattern at all. It's how things
          actually are.
        </p>
      </.section>

      <.section number="4" id="physics" title="The rabbit hole">
        <p class="text-sm text-base-content/65 leading-relaxed">
          Two events. In one frame they happen at the same instant; in
          another, they don't. Slide the slider. Simultaneity itself slides.
          There's no fact of the matter without specifying the frame -- the
          "when" of an event lives between the event and an observer.
        </p>

        <Splashes.reskinning_splash />

        <p class="text-sm text-base-content/65 leading-relaxed">
          Go further. A particle's position isn't a number it carries
          around; it's a number it produces relative to a measurement. Two
          systems that interact establish facts that are real between them
          and not absolute anywhere else. The math is unbothered. The
          intuition takes longer.
        </p>

        <Splashes.subtraction_splash />

        <p class="text-sm text-base-content/65 leading-relaxed italic">
          This is not a thought experiment. This is the picture our deepest
          theories are converging on.
        </p>
      </.section>

      <.section number="5" id="synthesis" title="Synthesis">
        <p class="text-sm text-base-content/65 leading-relaxed">
          Three different things. The same pattern under each one.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          A color was a relationship between a light, a surface, an eye, and
          a word. A flock was a relationship between birds. A particle was a
          relationship between systems.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          In each case you started by looking at the thing. In each case the
          thing turned out to be a placeholder for the structure that was
          actually doing the work.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed italic">
          What if that's not three coincidences?
        </p>
      </.section>

      <.section number="6" id="closer">
        <p class="text-sm text-base-content/65 leading-relaxed">
          You noticed the gray was in the relationship, not the square. You
          watched a flock outlive the birds in it. You deleted everything
          and the diagram still pointed somewhere.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed italic">
          The relations were always the thing. They were always the only thing.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed italic">
          You knew this when you saw the squares.
        </p>
      </.section>
    </article>
    """
  end

  attr :number, :string, default: nil
  attr :id, :string, required: true
  attr :title, :any, default: nil

  slot :inner_block, required: true

  defp section(assigns) do
    ~H"""
    <section id={@id} class="mb-24">
      <h2
        :if={@title}
        class="text-sm font-semibold uppercase tracking-widest text-base-content/85 mb-4"
      >
        {@title}
      </h2>

      <div class="space-y-5">
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end
end
