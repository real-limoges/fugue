# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Install deps and build assets (first-time setup)
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

# Pre-commit check: compile (warnings-as-errors) + format + test
mix precommit

# Format Elixir code
mix format

# Rebuild Bloom WASM (run inside assets/vendor/bloom/)
wasm-pack build --target web
# With SIMD:
RUSTFLAGS="-Ctarget-feature=+simd128" wasm-pack build --target web

mix ecto.migrate          # run pending migrations
mix ecto.setup            # create DB + migrate (first-time)
mix ecto.reset            # drop + recreate + migrate
mix ecto.gen.migration name_of_migration  # generate a new migration
```

`mix precommit` runs in the `:test` env (set by `preferred_envs` in mix.exs).

## Architecture

### Ecto + SQLite

**`Fugue.Repo`** is a standard `Ecto.Repo` backed by `ecto_sqlite3`. The single database lives at `priv/graph_data/fugue.db` (WAL mode). Migrations are in `priv/repo/migrations/`.

**`Fugue.Graph.Loader`** sits on top of `Fugue.Repo` and provides the domain-level API: `load_subgraph/2`, `search_articles/1`, `get_article/1`. FTS5 search and BFS subgraph expansion use raw SQL via `Repo.query/2` since Ecto has no built-in support for these SQLite-specific constructs.

Schemas: `Fugue.Graph.Article`, `Fugue.Graph.Link`, `Fugue.Graph.Category`, `Fugue.Graph.ArticleCategory`.

### Bloom — Rust→WASM Graph Renderer

Bloom is a git submodule at `assets/vendor/bloom/`. The compiled WASM output (`pkg/`) is committed to that repo and consumed directly by esbuild via an import alias. The LiveView hook imports from `../vendor/bloom/pkg/bloom.js`.

The data flow for the graph tool: SQLite → `Graph.Loader` → Elixir encodes BLOM binary → pushes over WebSocket → Bloom WASM decodes and renders with wgpu (WebGPU/WebGL2).

### Supervision Tree

```
Fugue.Supervisor
├── FugueWeb.Telemetry
├── DNSCluster
├── Phoenix.PubSub
├── Fugue.Repo          ← Ecto.Repo (ecto_sqlite3), single fugue.db
└── FugueWeb.Endpoint
```

### Frontend

- **HTTP server:** Bandit (not Cowboy)
- **Assets:** esbuild (ES2022 target) + Tailwind v4, both run as watchers in dev
- **JS entry:** `assets/js/app.js`
- **Live reload:** watches `lib/fugue_web/(controllers|live|components)/` and `priv/static/`

### Planned Tools (not yet implemented)

- **Probalisp** — Common Lisp via Erlang port, will be a GenServer in `lib/fugue/probalisp/`
- **Funktor** — Haskell via Erlang port, will copy Probalisp's GenServer pattern
- **Chirplet** — Julia (offline) + Rust→WASM (runtime DSP), will copy Bloom's WASM architecture

See `docs/architecture.md` and `docs/roadmap.md` for full integration plans.