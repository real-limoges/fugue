# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# First-time setup: install deps, build assets, create + migrate DB
mix setup

# Start dev server (auto-reloads Elixir, JS, CSS)
mix phx.server
iex -S mix phx.server

# Run all tests
mix test

# Run a single test file
mix test test/fugue_web/controllers/page_controller_test.exs

# Run a single test by line number
mix test test/fugue_web/controllers/page_controller_test.exs:12

# Pre-commit check: compile (warnings-as-errors) + unlock unused deps + format + test
mix precommit

# Format Elixir code
mix format

# Database operations
mix ecto.migrate                          # run pending migrations
mix ecto.setup                            # create DB + migrate
mix ecto.reset                            # drop + recreate + migrate
mix ecto.gen.migration name_of_migration  # generate a new migration

# JS dependencies (for Cosmograph, etc.)
cd assets && npm install
```

`mix precommit` runs in the `:test` env (set by `preferred_envs` in mix.exs).

## Architecture

### What Fugue Is

Fugue is the Phoenix/Elixir orchestration layer for [realcomplex.systems](http://realcomplex.systems) — a portfolio of six services (Bloom, Funktor, Ish, Garçon, Chirplet) plus two shared Haskell libraries (Hazy, Chompsky). Fugue serves the website, handles routing, and will eventually coordinate cross-service communication.

Currently only the Bloom (graph visualization) integration is active. The other services are at various stages in their own repos.

### Ecto + SQLite

`Fugue.Repo` is a standard `Ecto.Repo` backed by `ecto_sqlite3`. The database lives at `priv/graph_data/fugue.db` (WAL mode, 64MB cache). Migrations are in `priv/repo/migrations/`.

`Fugue.Graph.Loader` provides the domain API: `load_subgraph/2`, `search_articles/1`, `get_article/1`. FTS5 search and BFS subgraph expansion use raw SQL via `Repo.query/2` — Ecto has no built-in support for these SQLite-specific constructs.

Schemas: `Fugue.Graph.Article`, `Fugue.Graph.Link`, `Fugue.Graph.Category`, `Fugue.Graph.ArticleCategory`.

### Bloom — Graph Visualization

Graph rendering uses **Cosmograph** (`@cosmograph/graph`), a WebGL-based graph visualization library. The JS dependency is in `assets/package.json`.

The LiveView hook is at `assets/js/hooks/graph_viz.js`. Data flow: SQLite → `Graph.Loader` → LiveView pushes JSON over WebSocket → Cosmograph renders.

The underlying graph data comes from **Dedalus** (separate Rust repo) which extracts Wikipedia XML into the SQLite database.

### Supervision Tree

```
Fugue.Supervisor
├── FugueWeb.Telemetry
├── DNSCluster
├── Phoenix.PubSub
├── Fugue.Repo          ← ecto_sqlite3, single fugue.db
└── FugueWeb.Endpoint   ← Bandit adapter
```

### Frontend

- **HTTP server:** Bandit (not Cowboy)
- **Assets:** esbuild (ES2022 target) + Tailwind CSS v4, both run as watchers in dev
- **UI framework:** DaisyUI (vendored JS plugin at `assets/vendor/daisyui.js`)
- **JS entry:** `assets/js/app.js`
- **Live reload:** watches `lib/fugue_web/(controllers|live|components)/` and `priv/static/`

### Deployment

Target is GCP Cloud Run (scale-to-zero, serverless). Docker Compose config exists for local multi-service development — currently wires up Fugue only, with commented stubs for sibling services.

The `docker-entrypoint.sh` runs Ecto migrations before starting the release.

## Sibling Services

These are separate repos, not part of this codebase, but useful context:

| Service | Language | Role | Status |
|---------|----------|------|--------|
| Hazy | Haskell | Fuzzy logic library (shared dep) | Done |
| Chompsky | Haskell | Lua-configured NLP parser | Done |
| Bloom | Rust + WASM | Wikipedia graph data extraction | ~50% |
| Funktor | Haskell | Algorithmic jazz + Launchpad Mini | ~50% |
| Ish | Haskell | Mood tracking (uses Hazy) | Scaffolded |
| Garçon | Haskell | Servant wrapper for Chompsky + Hazy | Not started |
| Chirplet | Julia | Birdsong DSP via xeno-canto | Not started |

## Style & Conventions

- Phoenix 1.8 with LiveView — prefer LiveView for interactive features
- Bandit over Cowboy — already configured, don't switch
- Tailwind v4 + DaisyUI — use utility classes and DaisyUI components
- `mix precommit` is the quality gate: warnings-as-errors, format check, full test suite
- Raw SQL is acceptable for SQLite-specific features (FTS5, recursive CTEs, etc.)
- Config splits: `config.exs` (shared), `dev.exs`, `test.exs`, `prod.exs`, `runtime.exs` (env vars)