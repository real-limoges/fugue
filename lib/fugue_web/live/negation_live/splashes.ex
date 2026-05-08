defmodule FugueWeb.NegationLive.Splashes do
  @moduledoc """
  Function components for each /negation section's splash figure. v0
  storyboard pass: every splash is a placeholder figure that reserves
  space and labels what will land. Pure Phoenix.Component -- no LiveView
  state. State, hooks, and real visuals arrive when the splashes get
  built for real (see lib/fugue_web/live/negation/STUBS.md).
  """

  use Phoenix.Component

  # ----- Section 1 hero: the sentence as a quotable display block -----

  def hero_quote_splash(assigns) do
    ~H"""
    <figure class="space-y-3">
      <div class="w-full rounded border border-base-content/10 bg-base-200/30 px-6 py-12 flex items-center justify-center">
        <blockquote class="font-mono text-xl sm:text-2xl text-base-content/80 text-center">
          I haven't seen nobody nowhere.
        </blockquote>
      </div>
    </figure>
    """
  end

  # ----- Section 3 major: sentence-mixer (placeholder) -----
  # Real version: language selector across English (Standard / Older / AAVE),
  # Polish, Spanish, Afrikaans, French (literary). Each constituent toggles
  # its negation morphology and faint arcs draw the agreement chains.
  # Bottom line flips between "negation" and "positive" when the language
  # cancels.

  def sentence_mixer_splash(assigns) do
    ~H"""
    <figure class="space-y-3">
      <div class="w-full rounded border border-base-content/10 bg-base-300/40 p-12 min-h-64 flex items-center justify-center">
        <span class="font-mono text-xs uppercase tracking-widest text-base-content/40 text-center">
          sentence-mixer placeholder<br /> language selector + agreement chains
        </span>
      </div>
      <figcaption class="font-mono text-xs text-base-content/45 leading-relaxed not-italic">
        Drag and toggle constituents. Switch language. Watch negation
        rearrange.
      </figcaption>
    </figure>
    """
  end

  # ----- Section 4 micro: Lowth 1762 quotation (placeholder) -----
  # Real version: a styled excerpt from Lowth's _Short Introduction to
  # English Grammar_ on double negation, with one tap revealing his other
  # rules English speakers ignore (split infinitives, ending sentences
  # with prepositions, etc.).

  def lowth_quote_splash(assigns) do
    ~H"""
    <figure class="space-y-3">
      <div class="w-full rounded border border-base-content/10 bg-base-300/40 p-10 min-h-48 flex items-center justify-center">
        <span class="font-mono text-xs uppercase tracking-widest text-base-content/40 text-center">
          Lowth 1762 placeholder<br /> the rule, in its original context
        </span>
      </div>
    </figure>
    """
  end
end
