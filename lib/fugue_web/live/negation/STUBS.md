# Negation chapter -- stub notes

Per-section drafting notes. Pair with `CLAUDE.md` in this directory for the
full design plan.

## Section 1 -- Hero

Storyboard ships the sentence itself as the hero figure: *I haven't seen
nobody nowhere.* No interaction. v1 prose around it lands the flinch and
immediately complicates it (Chaucer, most living languages, pre-1700s
English). No personal thread here.

Open: whether the Chaucer micro-splash (line + four-negative highlight on
hover) lives here in section 1 or moves to section 4 alongside Lowth.
Currently neither -- skip until prose pass decides.

## Section 2 -- Concord and cancellation

Mechanism section. Two operating principles, one parameter. Concord
languages: Polish, Russian, Spanish, Greek, Italian, Afrikaans, AAVE,
older English. Cancellation languages: standard English, standard
German, formal written French.

Personal thread surfaces once: *"I grew up being corrected for sentences
my grammar wanted to make."* Verbatim from CLAUDE.md. Don't elaborate.

No splash. The mechanism is prose. v1 ships rough; tighten on next pass.

## Section 3 -- The sentence-mixer

The chapter's only major splash. v0 ships a placeholder figure.

v1 build: single interactive surface, sentence template along the lines
of `[I] [didn't] [see] [anybody] [anywhere].`, language selector across
English (Standard / Older / AAVE), Polish, Spanish, Afrikaans, French
(literary). Each constituent has a small affordance (toggle / cycle).
Switching language rearranges morphology and lights faint agreement
arcs between negative elements. Bottom line shows current MEANING
(negation vs. positive) and flips when a cancellation language stacks.

Data: hand-authored declarative table of 5-6 sentences across languages
with morpheme-level alignment. Don't try to parse arbitrary input.

Open from CLAUDE.md: how many languages (5 vs. 6 with French), AAVE
framing (treat exactly like Polish), agreement chains default-on or
default-off (lean default-on with a dim toggle).

## Section 4 -- Logic was the wrong frame

Lowth 1762, the prescriptive rule, the math metaphor as category error.
Keep short. Don't preach.

v0 ships a small placeholder for the Lowth excerpt. v1 micro-splash
(optional): styled reproduction of the original sentence on double
negation with one tap to reveal his other rules English speakers
ignore today (split infinitives, sentence-final prepositions). Skip
if it makes the section feel like a debunking.

## Section 5 -- What your grammar decided for you

The pattern beyond negation. Three quick examples, then back to
negation.

- Evidentiality (Tuyuca, Quechua): grammar makes you commit to
  source.
- Aspect over tense (Mandarin, Russian): complete vs. ongoing
  privileged over when.
- Inclusive vs. exclusive "we" (Austronesian languages, Quechua,
  Tok Pisin): two words English blurs.

Then back to Polish vs. standard English on totality of nothing.

Personal thread, plainly: *"I have spent a lot of time wanting to
say things English had quietly decided I couldn't."* Verbatim from
CLAUDE.md. Don't elaborate. Let it sit.

No splash. Prose only.

## Section 6 -- A worn path

Closer. Short. The metaphor: grammar is a worn path through a field.
The path makes some routes effortless and others feel like trespass.
Walking other languages' paths changes what you notice is in the
field.

Callback to the opening sentence. Same eight words, different path
underneath.

No splash.

## Open questions (from CLAUDE.md, not yet decided)

1. Title -- "Negation" is functional; alternatives include "Nobody
   Nowhere," "The Worn Path," "Concord," "Two Negatives." Currently
   shipping as "Negation."
2. Where this chapter sits in the chapter order on the site.
3. AAVE in the splash -- treat exactly like Polish, neutral.
4. How many languages in the splash -- five or six (French earns its
   slot only if the cancellation register is doing work the others
   don't).
5. Whether agreement chains are default-on or default-on-with-dim.

## What this chapter is not (from CLAUDE.md)

- Not a linguistics tutorial. No syntactic trees, no IPA, no formal
  feature notation.
- Not a memoir. Personal thread is structural, two sentences total,
  placed at structural joints.
- Not a takedown of prescriptivism. The argument is bigger and
  quieter than that.
- Not parser-driven. The eventual /parse work is its own thing.
