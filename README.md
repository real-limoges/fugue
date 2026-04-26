# Fugue

The orchestration layer and public face of [realcomplex.systems](http://realcomplex.systems) — a multi-service portfolio that demonstrates emergent complexity through interactive computational systems.

Fugue is a Phoenix/Elixir application that serves the website and coordinates six independent services, each built in the language best suited to its domain. The name borrows from the musical form: independent voices entering one at a time, each self-contained, building toward something larger than any individual part.

## Services

### Funktor — Algorithmic Jazz
Generative jazz composition with Launchpad Mini hardware integration.

- **Stack:** Haskell (Servant API, music generation), Tone.js (browser audio), CoreMIDI → C bridge → Haskell (hardware input)
- **Frontend:** Virtual Launchpad Mini grid in browser
- **Status:** ~50% complete

### Ish — Mood Tracking
The gravitational center of the system. A mood tracking microservice that uses fuzzy logic to model emotional states as gradients rather than categories. Fugue consumes it via the `/mood` LiveView, which turns four years of the author's own daily self-ratings into a multi-chapter visual essay.

- **Stack:** Haskell (Servant API), Hazy (fuzzy logic library)
- **Frontend:** `/mood` explorer — PCA trajectory hero (one scribble for the whole run), interactive fuzzy-clustering sandbox, calendar heatmap with transition borders, hysteresis-smoothed transition timeline and sankey, per-month "mood flower" radars, and a breath timeline of silences
- **Status:** Live. Ish backend exposes `/data`, `/cluster`, `/gaps`; Fugue handles all visualization client-side via D3

### Garçon — NLP + Fuzzy Logic API
A Haskell Servant wrapper that exposes Chompsky (NLP parser) and Hazy (fuzzy logic) as HTTP endpoints.

- **Stack:** Haskell (Servant), Chompsky (Lua-configured parser), Hazy
- **Status:** In progress

### Chirplet — Birdsong Dialect Analysis
DSP analysis of bird vocalizations using xeno-canto field recording data.

- **Stack:** Julia (signal processing, spectrogram generation), xeno-canto API
- **Status:** Not started

### Hazy — Fuzzy Logic Library
Shared Haskell dependency used by Ish and Garçon. Models continuous/gradient states rather than binary ones.

- **Status:** Essentially done

### Chompsky — NLP Parser
Lua-configured natural language parser, exposed through Garçon.

- **Status:** Done

## Architecture

```
┌─────────────────────────────────────────────────────┐
│              Fugue — Phoenix/Elixir                  │
│         (Routing, LiveView UI, API Gateway)          │
└────────────────┬────────┬────────┬─────────┬────────┘
                 │        │        │         │
                 ▼        ▼        ▼         ▼
              ┌───────┐ ┌────┐ ┌───────┐ ┌────────┐
              │Funktor│ │Ish │ │Garçon │ │Chirplet│
              │Haskell│ │HSK │ │Haskell│ │Julia   │
              │+Tone  │ │    │ │       │ │        │
              └───────┘ └──┬─┘ └──┬────┘ └────────┘
                            │      │
                            ▼      ▼
                         ┌──────────────┐
                         │  Hazy        │
                         │  (fuzzy logic)│
                         └──────────────┘
```

Each service is isolated — developed and deployed independently. Cross-service connections (Ish mood state shaping Funktor's jazz parameters, etc.) are aspirational and expected to emerge from use rather than upfront design.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Web framework | Phoenix 1.8 / Elixir, LiveView |
| HTTP server | Bandit |
| Jazz generation | Funktor (Haskell), Tone.js, Launchpad Mini |
| Mood tracking | Ish (Haskell), Hazy (fuzzy logic) |
| NLP | Chompsky (Lua-configured parser), Garçon (Haskell Servant) |
| Birdsong DSP | Chirplet (Julia), xeno-canto |
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
│   ├── fugue/               # Service clients (Ish, etc.)
│   └── fugue_web/
│       ├── live/            # LiveView modules
│       ├── components/      # Shared UI components
│       └── router.ex
├── assets/
│   ├── js/                  # app.js entry + hooks
│   ├── css/
│   └── vendor/
├── config/
├── priv/
└── docs/                    # Architecture & planning docs
```

## Related Repositories

- Funktor, Ish, Garçon, Chirplet, Hazy, Chompsky — sibling repos in the realcomplex.systems family

## Development

```bash
# Pre-commit: compile (warnings-as-errors) + format + test
mix precommit

# Format code
mix format

# Run tests
mix test
```