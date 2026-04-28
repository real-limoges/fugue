defmodule FugueWeb.ColorLive do
  use FugueWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Color")
     |> assign(
       :meta_description,
       "Color is a transaction between light, eye, screen, and word."
     )}
  end

  def render(assigns) do
    ~H"""
    <article class="px-4 py-8 max-w-3xl mx-auto text-base-content/90 space-y-24">
      <header class="space-y-4">
        <p class="font-mono text-xs tracking-widest uppercase text-primary/70">
          A chapter
        </p>
        <h1 class="text-4xl sm:text-5xl font-semibold tracking-tight text-white">
          Color is a transaction.
        </h1>
        <p class="font-mono text-xs text-base-content/40">
          [stub: framing tagline only — full intro deferred]
        </p>
      </header>

      <.section number="1" id="prism" title="The prism">
        <:splash label="§1 — prism (WASM/C dispersion)" aspect="aspect-[16/9]" />
        <p class="text-lg leading-relaxed">This is where color begins.</p>
        <.stub_note>
          Hero splash. Drag-to-tilt prism, real dispersion math via WASM.
          No author yet, no qualifications. The reader is allowed the easy story.
        </.stub_note>
      </.section>

      <.section number="2" id="eye" title="The eye's guesses">
        <:splash label="§2 — cone response curves + protanope toggle" aspect="aspect-[16/10]" />
        <.stub_note>
          The single fuzzy-frame sentence lands here — load-bearing for the rest of
          the chapter. Cone curves as overlapping membership functions over wavelength.
          Protanope toggle introduced; reused in §3 and §6. Brief mention of contingent
          channel count (tetrachromats, mantis shrimp).
        </.stub_note>
      </.section>

      <.section number="3" id="metamerism" title="Metamerism">
        <:splash label="§3 — metamer pair (toggle carries through)" aspect="aspect-[16/9]" />
        <.stub_note>
          Two patches, identical to a trichromat eye, spectrally distinct underneath.
          Toggle from §2 flips the match. Two short captions, no reflective paragraph —
          the splash makes the point. First real punch of the chapter.
        </.stub_note>
      </.section>

      <.section number="4" id="gamut" title="The gamut horseshoe">
        <:splash label="§4 — CIE chromaticity + sRGB / P3 / Rec.2020" aspect="aspect-square" />
        <.stub_note>
          Cut candidate if the chapter runs long. One sentence acknowledging the
          diagram is itself a trichromat artifact; trust the reader to remember §2.
        </.stub_note>
      </.section>

      <.section number="5" id="language" title="Language carves it up">
        <:splash
          label="§5a — WCS chip grids (Berinmo + English baseline + 2–3 more)"
          aspect="aspect-[16/9]"
        />
        <:splash label="§5b — Russian / Hungarian / Welsh illustrations" aspect="aspect-[16/9]" />
        <.stub_note>
          Two registers kept visibly distinct: WCS data with consensus opacity
          (Berinmo, not Himba) vs. hand-curated illustrations from secondary
          literature. Yélî Dnye prose beat. Up to two short personal lines —
          drop one if it crowds.
        </.stub_note>
      </.section>

      <.section number="6" id="remainder" title="The remainder">
        <:splash
          label="§6 — protanope toggle returned (the splash deliberately fails)"
          aspect="aspect-[16/9]"
        />
        <.stub_note>
          Hardest writing problem in the chapter — budget more drafting passes
          than the other six combined. The chain is public; the having is not.
          Mary's Room inversion line lands AFTER the remainder argument is made.
          No Nagel, no Jackson by name.
        </.stub_note>
      </.section>

      <.section number="7" id="closer" title="Closer">
        <:splash label="§7 — prism returned (reuses §1)" aspect="aspect-[16/9]" />
        <p class="text-lg leading-relaxed">Color is a transaction.</p>
        <.stub_note>
          Four parties named: light, eye, screen, word. The fifth is the remainder,
          deliberately left off. Short.
        </.stub_note>
      </.section>
    </article>
    """
  end

  attr :number, :string, required: true
  attr :id, :string, required: true
  attr :title, :string, required: true

  slot :splash do
    attr :label, :string, required: true
    attr :aspect, :string, required: true
  end

  slot :inner_block, required: true

  defp section(assigns) do
    ~H"""
    <section id={@id} class="space-y-6">
      <div class="flex items-baseline gap-4 border-b border-base-content/10 pb-2">
        <span class="font-mono text-xs text-primary/60 tracking-widest">§{@number}</span>
        <h2 class="text-2xl font-semibold text-white tracking-tight">{@title}</h2>
      </div>

      <div
        :for={s <- @splash}
        class={[
          "w-full rounded border-2 border-dashed border-base-content/20 bg-base-200/30 flex items-center justify-center",
          s.aspect
        ]}
      >
        <span class="font-mono text-xs text-base-content/40 tracking-wider px-4 text-center">
          {s.label}
        </span>
      </div>

      <div class="prose prose-invert max-w-none space-y-4">
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end

  slot :inner_block, required: true

  defp stub_note(assigns) do
    ~H"""
    <p class="font-mono text-xs text-base-content/40 border-l-2 border-base-content/20 pl-3 italic">
      [stub] {render_slot(@inner_block)}
    </p>
    """
  end
end
