# Relational chapter -- stub notes

Per-section drafting notes. Pair with `CLAUDE.md` in this directory for the
full design plan.

## Build state

- [x] Route `/relation` wired (`router.ex`)
- [x] LiveView skeleton with all 6 sections (`relation_live.ex`)
- [x] First-pass rough prose -- opener + closing aphoristic beat per section
- [x] Splash placeholder boxes shipped (storyboard pass)
- [ ] Long-read warning copy calibrated (current: "Heads up. This is the long one... pack a snack.")
- [ ] Section 1 splash -- contextual gray squares (verifiable identity)
- [ ] Section 2 splash -- drag-and-build perception chain
- [ ] Section 3 splash -- fading boid (agents fade, field remains)
- [ ] Section 4 splash A -- reskinning (dots/arrows toggle meaning)
- [ ] Section 4 splash B -- subtraction (delete nodes, structure survives)
- [ ] Micro: frame-dependence slider (Section 4 opener)
- [ ] Micro: identity-by-neighborhood (Section 3 reinforcer)

## Section 1 -- Opening hook (gray squares)

v1 prose is rough. The closing italic question is the load-bearing line:
*"if the gray was in the square, why does it change when nothing in the
square changed?"*. Splash needs to make the verification trivial -- finger-
cover or a "show equality" toggle that collapses the surrounds to a flat
field.

No section title rendered (opens cold).

## Section 2 -- Perception

Real opening paragraph in place. Tour of contextual phenomena planned but
not drafted. End-of-section bait line ("Maybe perception is just a special
case") kept verbatim from design plan.

Splash reuse path: drag patch into surrounds, build chains where each step
looks different but is identical to a step two back. Adapt
`assets/js/hooks/temporal_brush.js` D3 drag pattern for the drag.

## Section 3 -- Systems

Hinge section. Two splashes planned: fading boid (primary, emotional turn),
identity-by-neighborhood (reinforcer, smaller). End beat is the explicit
"you can stop here" -- this is the side break. Real, not performative.

Splash reuse path: fork `lib/fugue_web/live/menagerie_live/boids.ex` and
`assets/js/hooks/boids_canvas.js`; layer alpha + vector overlay so the
agents fade and the relational field survives.

## Section 4 -- The rabbit hole

Longest section. Opens with frame-dependence (relativity), goes deeper into
properties-as-relations. Two splashes (reskinning, subtraction) plus a
possible micro (frame-dependence slider).

Per design plan, the chapter never names the framework -- no
category-theoretic vocabulary, no RQM / Rovelli / structural realism. The
picture lands without the names.

End beat verbatim from design plan: *"This is not a thought experiment.
This is the picture our deepest theories are converging on."*

Splash reuse path:
- Reskinning -- pure server-rendered SVG, palette swap pattern from
  `lib/fugue_web/live/mood_live/cluster_radar.ex`.
- Subtraction -- bespoke force-directed; helper math available in
  `lib/fugue_web/live/mood_live/svg_math.ex`.

## Section 5 -- Synthesis

Names what the reader has seen, in plain language. No new visual. Closes
on *"What if that's not three coincidences?"*.

## Section 6 -- Closer

Quiet exit. No section title rendered. Callbacks to gray squares + deleted
network. Last line is verbatim from design plan: *"You knew this when you
saw the squares."*

## Open questions

- [ ] **Title.** Design plan leans "Underneath." Stub uses "Relational" as
      placeholder; final pick deferred.
- [ ] **Bespoke vs. Petri boid** for splash 3. Design plan leans bespoke
      (smaller, fits chapter pacing); Petri reuse cheaper.
- [ ] **Frame-dependence depth** in section 4 (quick stop vs. real arc).
      Decide during prose pass.
- [ ] **No personal thread** -- design plan rules this out. Revisit only
      if the chapter starts to feel cold during drafting.
- [ ] **Long-read warning copy** -- calibrate during prose pass. Current
      reads slightly chatty; could go terser.

## Tone guardrails

- ASCII only.
- Never name the framework. No category theory, monad/functor/morphism,
  RQM, Rovelli, structural realism. Intuition before terminology.
- Fragments OK. Semicolons OK. Deadpan-by-rhythm.
- No manufactured aphorism closes; end-of-section beats are taken from the
  design plan, which already has the right register.
- No puns. No wordplay.
- No "color is a transaction"-style academic framings.
