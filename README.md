# Fugue

The Phoenix LiveView app behind [realcomplex.systems](https://realcomplex.systems): a personal site of interactive pieces about emergent systems, where many small agents or constraints produce a surprising whole.

Everything runs in this one app.
The fuzzy-logic and mood-analysis math that used to live in separate Haskell services (Hazy and Ish) is now plain Elixir in `Fugue.Fuzzy` and `Fugue.Mood`, and the heavier color and modeling code ships as vendored WASM.

## What's on the site

| Route | What it is |
| --- | --- |
| `/mood` | Four years of the author's daily mood ratings, fuzzy-clustered and drawn as a multi-chapter visual essay |
| `/color` | A colorblind narrator's tour of color science, from cones to the World Color Survey |
| `/menagerie` | Small emergent-systems toys: boids, sandpile, fuzzy sets, a Mamdani controller, a quantum walk |
| `/lab` | Self-contained experiments: generalized additive models, Bayesian updating |
| `/amigos` | An *Arrested Development* recap that keeps adding annotation as you scroll |
| `/about`, `/code` | Who made it, and the repos that run it |
| `/feed.xml` | RSS feed of updates |

## Running it

```bash
mix setup          # deps, npm assets, WASM copies, first build
mix phx.server     # http://localhost:4000
```

## Checks

```bash
mix precommit
```

That is what CI runs: compile and test with warnings as errors, a formatting check, Credo, a Prettier check, the vitest suite in `assets/test/`, and the ExUnit suite with a coverage report.
It only checks; `mix format` and `mix assets.format` fix formatting.
It needs `mix setup` first, because Prettier and vitest live in `assets/node_modules/`.

The toolchain is pinned in `.tool-versions`, the `Dockerfile` and `.github/workflows/ci.yml`; keep the three in step.

## Layout

```
lib/fugue/          Domain code with no web dependency: fuzzy and mood math,
                    color science, menagerie and lab math, the /amigos data
lib/fugue_web/      Router, controllers, components, and one LiveView per page
lib/mix/tasks/      fugue.color.gen, which turns Timbre's data into lib/fugue/color/wcs.ex
assets/js/          app.js, LiveView hooks, shared canvas helpers
assets/test/        vitest tests for the pure JS helpers
assets/vendor/      Upstream drops (petri, glissando, chirplet); fix them upstream
priv/static/        Bundled datasets and static files
```

## Color data

`/color` section 5 renders World Color Survey data prepared by [Timbre](https://github.com/real-limoges/Timbre).
To refresh it, run `make sync-fugue FUGUE=/path/to/fugue` in the Timbre repo, which drops per-language grids into the gitignored `priv/color/`, then regenerate the committed module here:

```bash
mix fugue.color.gen
```

Don't edit `lib/fugue/color/wcs.ex` by hand.

## Related repositories

- [petri](https://github.com/real-limoges/petri): color-science and simulation WASM, vendored at `assets/vendor/petri/`
- [glissando](https://github.com/real-limoges/glissando): GAM models with a WASM backend, vendored at `assets/vendor/glissando/`
- [Timbre](https://github.com/real-limoges/Timbre): World Color Survey aggregation (Python), build-time only
- [chirplet](https://github.com/real-limoges/chirplet): birdsong DSP (Julia), vendored as a preview and not yet wired in
- [real-complex](https://github.com/real-limoges/real-complex): Cloud Run deploy and production environment variables
