defmodule FugueWeb.RelationLive.Splashes do
  @moduledoc """
  Stub splash components for /relation. Each function returns an
  ASCII-bordered placeholder figure with the splash name and the goal-line
  caption from the chapter design plan, so the page reads like a storyboard
  while the real splashes get built section by section.

  See `lib/fugue_web/live/relation/CLAUDE.md` for the build plan and
  `STUBS.md` for per-section reuse paths.
  """

  use Phoenix.Component

  # ----- Section 1: contextual gray squares -----

  def gray_squares_splash(assigns) do
    ~H"""
    <.placeholder
      name="gray squares"
      goal="the reader cannot unsee the question."
    />
    """
  end

  # ----- Section 2: drag-and-build perception chain -----

  def perception_chain_splash(assigns) do
    ~H"""
    <.placeholder
      name="perception chain"
      goal="the reader feels the property moving as the relations change."
    />
    """
  end

  # ----- Section 3: boid that fades to field -----

  def fading_boid_splash(assigns) do
    ~H"""
    <.placeholder
      name="fading boid"
      goal="the reader feels something they don't have words for."
    />
    """
  end

  # ----- Section 4: reskinning toggle -----

  def reskinning_splash(assigns) do
    ~H"""
    <.placeholder
      name="reskinning"
      goal="same diagram, three domains. structure is the invariant."
    />
    """
  end

  # ----- Section 4: subtraction (delete nodes, structure survives) -----

  def subtraction_splash(assigns) do
    ~H"""
    <.placeholder
      name="subtraction"
      goal="the reader has just deleted reality and watched it survive."
    />
    """
  end

  # TODO micro-splashes:
  # - frame_dependence_splash/1 -- two events + observer-velocity slider; simultaneity slides.
  # - identity_by_neighborhood_splash/1 -- hover two nodes to reveal connections; structural identity vs. cosmetic difference.

  # ----- Internal: shared placeholder figure -----

  attr :name, :string, required: true
  attr :goal, :string, required: true

  defp placeholder(assigns) do
    ~H"""
    <figure class="space-y-3">
      <div
        class="w-full rounded border border-dashed border-base-content/30 bg-base-200/30 px-4 py-10 flex flex-col items-center justify-center gap-3 font-mono"
        style="aspect-ratio: 5 / 3;"
      >
        <span class="text-xs uppercase tracking-widest text-base-content/45">
          [splash stub]
        </span>
        <span class="text-base text-base-content/75">
          {@name}
        </span>
        <span class="text-xs text-base-content/40">
          TODO: implement
        </span>
      </div>
      <figcaption class="font-mono text-xs text-base-content/55 leading-relaxed not-italic">
        goal: {@goal}
      </figcaption>
    </figure>
    """
  end
end
