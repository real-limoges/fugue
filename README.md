# Fugue

The orchestration layer and public face of [realcomplex.systems](http://realcomplex.systems), a multi-service portfolio that demonstrates emergent complexity through interactive computational systems.

Fugue is a Phoenix/Elixir application that serves the website and coordinates three independent services, each built in the language best suited to its domain, plus its own in-process fuzzy-logic/mood-analysis math. The name borrows from the musical form: independent voices entering one at a time, each self-contained, building toward something larger than any individual part.

## Mood Tracking (in-process, ported from Ish/Hazy)

The gravitational center of the site: a fuzzy-logic model of emotional states as gradients rather than categories, driving the `/mood` LiveView, which turns four years of the author's own daily self-ratings into a multi-chapter visual essay. This used to be a separate Haskell microservice (Ish, wrapping the Hazy fuzzy-logic library) called over HTTP; it's now `Fugue.Fuzzy`/`Fugue.Mood`, plain Elixir running in-process against a bundled dataset.

- **Stack:** Elixir (ported from Haskell/Hazy/Ish)
- **Frontend:** `/mood` explorer: PCA trajectory hero (one scribble for the whole run), interactive fuzzy-clustering sandbox, calendar heatmap with transition borders, hysteresis-smoothed transition timeline and sankey, per-month "mood flower" radars, and a breath timeline of silences
- **Status:** Live. `Fugue.Mood.Wire` computes clustering/gaps in-process; Fugue handles all visualization client-side via D3

## Services

### Garçon: NLP + Fuzzy Logic API
A Haskell Servant wrapper that exposes Chompsky (NLP parser) and Hazy (fuzzy logic) as HTTP endpoints.

- **Stack:** Haskell (Servant), Chompsky (Lua-configured parser), Hazy
- **Status:** In progress

### Chirplet: Birdsong Dialect Analysis
DSP analysis of bird vocalizations using xeno-canto field recording data.

- **Stack:** Julia (signal processing, spectrogram generation), xeno-canto API
- **Status:** Not started

### Hazy: Fuzzy Logic Library
Haskell dependency used by Garçon. Models continuous/gradient states rather than binary ones. (Fugue no longer depends on it directly -- `Fugue.Fuzzy` is a from-scratch Elixir port, not a client of this repo.)

- **Status:** Effectively done

### Chompsky: NLP Parser
Lua-configured natural language parser, exposed through Garçon.

- **Status:** Done

## Architecture

```
┌─────────────────────────────────────────────┐
│              Fugue: Phoenix/Elixir           │
│  (Routing, LiveView UI, in-process Fuzzy/    │
│   Mood math ported from Hazy/Ish, API GW)    │
└──────────────────────┬──────────┬───────────┘
                       │          │
                       ▼          ▼
                   ┌───────┐ ┌────────┐
                   │Garçon │ │Chirplet│
                   │Haskell│ │Julia   │
                   └──┬────┘ └────────┘
                      │
                      ▼
                   ┌──────────────┐
                   │  Hazy        │
                   │  (fuzzy logic)│
                   └──────────────┘
```

Each service is isolated, developed and deployed independently. Cross-service connections are aspirational and expected to emerge from use rather than upfront design.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Web framework | Phoenix 1.8 / Elixir, LiveView |
| HTTP server | Bandit |
| Mood tracking | `Fugue.Fuzzy` / `Fugue.Mood` (Elixir, ported from Hazy/Ish) |
| NLP | Chompsky (Lua-configured parser), Garçon (Haskell Servant) |
| Birdsong DSP | Chirplet (Julia), xeno-canto |
| Color data prep | Timbre (Python), World Color Survey |
| Styling | Tailwind CSS v4, DaisyUI |
| Build | esbuild (ES2022), Docker / Docker Compose |
| Deployment | GCP Cloud Run (scale-to-zero) |

## Getting Started

```bash
# Install dependencies, build assets, set up database
mix setup

# Start the development server
mix phx.server

# Or start inside IEx
iex -S mix phx.server
```

Visit [`localhost:4000`](http://localhost:4000).

## Project Structure

```
fugue/
├── lib/
│   ├── fugue/
│   │   ├── color/           # Pure-Elixir color compute (petri WASM + Timbre-generated WCS data)
│   │   ├── fuzzy/           # Fuzzy-logic math, ported from Hazy (Haskell)
│   │   ├── mood/            # Mood-analysis math, ported from Ish (Haskell)
│   │   └── menagerie/       # Static-card sim modules (e.g., fuzzy)
│   ├── fugue_web/
│   │   ├── live/            # Chapters: mood, color, menagerie, relation, negation, lab
│   │   ├── components/      # Shared UI components
│   │   ├── controllers/
│   │   └── router.ex
│   └── mix/tasks/           # Codegen (e.g., fugue.color.gen: Timbre JSON -> color/wcs.ex)
├── assets/
│   ├── js/                  # app.js + hooks (canvas hooks for animated cards)
│   ├── css/
│   └── vendor/petri/        # Vendor'd WASM (prism.wasm, cones.wasm)
├── config/
└── priv/
    ├── static/
    └── color/               # Gitignored: Timbre's synced WCS JSON, consumed by fugue.color.gen
```

## Related Repositories

**Services**
- [garcon](https://github.com/real-limoges/garcon): NLP + fuzzy HTTP wrapper (Haskell, Servant)
- [chirplet](https://github.com/real-limoges/chirplet): birdsong DSP (Julia + WASM/Rust)

**Libraries**
- [hazy](https://github.com/real-limoges/hazy): fuzzy-logic library (Haskell), used by garcon. `Fugue.Fuzzy` is a from-scratch Elixir port, not a client of this repo.
- [chompsky](https://github.com/real-limoges/chompsky): Lua-configured NLP parser, exposed via garcon

**Vendor'd in this repo**
- [petri](https://github.com/real-limoges/petri): color-science WASM (`assets/vendor/petri/`)
- [glissando](https://github.com/real-limoges/glissando): GAM models with optional WASM backend (`assets/vendor/glissando/`)

**Build-time data prep**
- [Timbre](https://github.com/real-limoges/Timbre): World Color Survey color-term aggregation (Python). `make sync-fugue` drops per-language WCS grids into the gitignored `priv/color/`; `mix fugue.color.gen` inlines them into the committed `lib/fugue/color/wcs.ex`, which the color chapter's section 5 renders. Regenerate after Timbre changes.

**Infrastructure**
- [real-complex](https://github.com/real-limoges/real-complex): Cloud Run deploy + prod env vars for the whole family

## Development

```bash
# Pre-commit: compile (warnings-as-errors) + format + test
mix precommit

# Format code
mix format

# Run tests
mix test
```

Color chapter section 5 renders World Color Survey data generated by
[Timbre](https://github.com/real-limoges/Timbre). To refresh it, run
`make sync-fugue FUGUE=/path/to/fugue` in the Timbre repo, then regenerate the
committed module here:

```bash
mix fugue.color.gen
```