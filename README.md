# Fugue

A Phoenix/Elixir web platform that integrates four specialized research and data science tools, each implemented in the language best suited to its domain. Phoenix handles routing, UI, and data serving; each tool runs as an independent backend service.

## Tools

### Bloom — Wikipedia Knowledge Graph
Visualize the link structure of Wikipedia as an interactive graph. Search for articles, explore their connections, and click nodes to see details.

- **Pipeline:** Wikipedia XML → [Dedalus](https://github.com/real-limoges/dedalus) (Rust extraction) → SQLite → Fugue (Elixir/BFS) → binary WebSocket → [Bloom](https://github.com/real-limoges/bloom) (Rust→WASM renderer)
- **Rendering:** GPU-accelerated via `wgpu` with WebGPU (Tier 1) and WebGL2 (Tier 2) fallback
- **Data protocol:** BLOM binary format — zero JSON parsing in the hot path
- **Layout:** Barnes-Hut force-directed simulation in WASM, with SIMD paths

### Probalisp — Probability Programming
Query interface for a Common Lisp probabilistic programming system.

- **Integration:** Port communication — Phoenix spawns and supervises an SBCL process
- **UI:** Form → result pattern via LiveView

### Funktor — Jazz Theory Analysis
Submit chord progressions and scales, get music theory analysis back.

- **Integration:** Port communication — Phoenix spawns and supervises a GHC-compiled binary
- **UI:** Modeled after the Probalisp UI

### Chirplet — Bird Song DSP
Upload audio recordings and get spectrograms and bird song analysis.

- **Integration:** Julia (offline preprocessing) → Rust→WASM (runtime DSP) → Elixir (data serving)
- **UI:** File upload → processing → spectrogram + audio playback

## Architecture

```
┌─────────────────────────────────────────────────┐
│           Phoenix/Elixir Web Layer              │
│  (Routing, Auth, UI, API Gateway, SQLite)       │
└─────────────────┬───────────────────────────────┘
                  │
    ┌─────────────┼─────────────┬─────────────┐
    │             │             │             │
    ▼             ▼             ▼             ▼
┌────────┐  ┌──────────────┐  ┌──────────┐  ┌──────────┐
│Probalisp│  │Dedalus+Bloom │  │ Funktor  │  │ Chirplet │
│(Lisp)   │  │(Rust→SQLite) │  │(Haskell) │  │(Julia+   │
│ Port    │  │  WASM+wgpu   │  │  Port    │  │ Rust WASM│
└────────┘  └──────────────┘  └──────────┘  └──────────┘
```

Each tool is isolated — bugs in one don't affect others, and each can be developed and tested independently.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Web framework | Phoenix/Elixir, LiveView |
| Database | SQLite (via exqlite), FTS5 for full-text search |
| Styling | Tailwind CSS |
| Graph visualization | Bloom (Rust→WASM), wgpu (WebGPU/WebGL2) |
| Graph data pipeline | Dedalus (Rust), Wikipedia XML |
| Probability engine | Probalisp (SBCL / Common Lisp) |
| Jazz analysis | Funktor (GHC / Haskell) |
| Bird song DSP | Chirplet (Julia + Rust WASM) |

## Getting Started

```bash
# Install dependencies and set up the database
mix setup

# Start the development server
mix phx.server

# Or start inside IEx
iex -S mix phx.server
```

Visit [`localhost:4000`](http://localhost:4000).

### Bloom / Graph Visualization

Bloom is included as a git submodule. After cloning:

```bash
git submodule update --init --recursive
```

To rebuild Bloom from source:

```bash
cd assets/vendor/bloom
wasm-pack build --target web
```

## Project Structure

```
fugue/
├── lib/
│   ├── fugue/
│   │   ├── graph/           # SQLite queries, BFS, search, BLOM encoder
│   │   ├── probalisp/       # Port server + query interface
│   │   ├── funktor/         # Port server + analysis interface
│   │   └── chirplet/        # WASM bridge + audio pipeline
│   └── fugue_web/
│       ├── live/            # LiveView modules for each tool
│       └── router.ex
├── assets/
│   └── vendor/
│       └── bloom/           # Bloom git submodule (Rust→WASM)
└── docs/                    # Architecture, roadmap, implementation plans
```

## Documentation

- [`docs/architecture.md`](docs/architecture.md) — System design, integration strategies, file layout
- [`docs/roadmap.md`](docs/roadmap.md) — Phased rollout plan and success criteria
- [`docs/bloom/`](docs/bloom/) — Bloom WASM engine: binary protocol, shaders, JS API
- [`docs/implementation-plans/`](docs/implementation-plans/) — Per-tool detailed plans
- [`docs/deployment/`](docs/deployment/) — Deployment guides (Cloud Run, GKE, SQLite strategies)
- [`docs/frontend-patterns.md`](docs/frontend-patterns.md) — LiveView UI patterns for data science tools

## Related Repositories

- [Bloom](https://github.com/real-limoges/bloom) — Rust→WASM graph visualization engine
- [Dedalus](https://github.com/real-limoges/dedalus) — Rust pipeline that extracts Wikipedia graph data
