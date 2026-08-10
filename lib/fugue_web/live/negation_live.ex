defmodule FugueWeb.NegationLive do
  use FugueWeb, :live_view

  alias FugueWeb.NegationLive.Splashes

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Negation")
     |> assign(
       :meta_description,
       "A chapter about negation as a structural choice languages make."
     )}
  end

  def render(assigns) do
    ~H"""
    <article class="px-4 py-8 max-w-3xl mx-auto">
      <header class="mb-16 max-w-2xl">
        <h1 class="text-3xl font-bold tracking-tight text-base-content">
          Negation.
        </h1>
        <p class="text-gray-500 mt-2 mb-10">
          Two negatives, one negation.
        </p>
      </header>

      <.section number="1" id="hero">
        <Splashes.hero_quote_splash />

        <p class="text-sm text-base-content/65 leading-relaxed">
          That sentence is wrong, if you went to school in English. It also
          comes out of Chaucer's pen unedited, six centuries back. Most
          living languages still build negation this way. The flinch is
          learned.
        </p>
      </.section>

      <.section number="2" id="mechanism" title="Concord and cancellation">
        <p class="text-sm text-base-content/65 leading-relaxed">
          A language picks a side. In one, negative words inside a clause
          agree with each other -- the way adjectives agree with nouns
          for gender. Multiple markers, one negation. Polish does this.
          Spanish does this. Russian, Greek, Italian, Afrikaans, AAVE,
          and most varieties of English before the 1700s did this.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          In the other, negatives compose like math. Two of them cancel.
          Standard English, standard German, the formal written register
          of French. This is a smaller club than people raised inside it
          tend to assume.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          I grew up being corrected for sentences my grammar wanted to
          make.
        </p>
      </.section>

      <.section number="3" id="sentence-mixer" title="The sentence-mixer">
        <p class="text-sm text-base-content/65 leading-relaxed">
          One sentence. Six languages. Watch the negation rearrange.
        </p>

        <Splashes.sentence_mixer_splash />

        <p class="text-sm text-base-content/65 leading-relaxed">
          Switch to Polish and the markers stack. Switch to standard
          English and try to stack them: the meaning flips. Try to make
          Polish cancel and you find there is no grammatical way to do
          it. The languages aren't disagreeing about the logic. They're
          using different rules to decide what counts as one negation.
        </p>
      </.section>

      <.section number="4" id="frame-shift" title="Logic was the wrong frame">
        <p class="text-sm text-base-content/65 leading-relaxed">
          The "two negatives make a positive" rule was popularized in
          1762 by Robert Lowth, an English bishop writing a grammar
          modeled explicitly on Latin and on arithmetic. He was selling
          a prescription as a description. It was never how English
          actually worked, and most English speakers still don't speak
          this way -- they speak the standardized written register,
          which is a sociolect.
        </p>

        <Splashes.lowth_quote_splash />

        <p class="text-sm text-base-content/65 leading-relaxed">
          Negation in natural language is closer to agreement than to
          arithmetic. Markers that agree with each other inside a clause,
          like gender or number, are doing one piece of grammatical
          work together. The math metaphor was a category error. It
          stuck because dressing language up as logic felt like a
          promotion.
        </p>
      </.section>

      <.section number="5" id="carving" title="What your grammar decided for you">
        <p class="text-sm text-base-content/65 leading-relaxed">
          Every grammar makes choices about what's easy and what's hard
          to say. Some examples beyond negation, briefly. In Tuyuca and
          some other Amazonian languages, you cannot make a statement
          without grammatically marking how you know it -- saw it, heard
          it, inferred it, hearsay. The grammar will not let you be
          vague about the source. Mandarin and Russian privilege whether
          an action is complete or ongoing over when it happened;
          English does the opposite. Most Austronesian languages have
          two words for "we" -- one that includes the listener, one
          that doesn't -- and English speakers blur them and confuse
          each other constantly.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          Then back to negation. The Polish speaker doesn't decide
          whether to stack negatives -- the grammar decides. The
          standard English speaker has been taught the opposite, and
          trying to express the totality of nothing -- the real nothing
          of "I haven't seen nobody nowhere ever" -- becomes awkward.
          The shape you reach for has been filed off.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          I have spent a lot of time wanting to say things English had
          quietly decided I couldn't.
        </p>
      </.section>

      <.section number="6" id="closer" title="A worn path">
        <p class="text-sm text-base-content/65 leading-relaxed">
          Grammar is a worn path through a field. The path makes the
          most-walked routes effortless. It also makes the off-path
          routes feel like trespass. Other languages have other paths
          through the same field, and walking them -- even badly, even
          as a learner -- changes what you notice is there.
        </p>

        <p class="text-sm text-base-content/65 leading-relaxed">
          I haven't seen nobody nowhere. In standard English it cancels.
          In older English, in AAVE, in most of the rest of the world's
          languages, it intensifies. The sentence didn't change. The
          path under it did.
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
