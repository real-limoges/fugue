# Build stage
FROM hexpm/elixir:1.17.3-erlang-26.2.2-ubuntu-noble-20260210.1 AS builder

# Install system dependencies needed for exqlite (C compilation) and assets (Node.js)
RUN apt-get update -q && \
    apt-get install -y --no-install-recommends \
      build-essential \
      nodejs \
      npm \
      git \
      ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod

# Fetch Elixir dependencies (layer-cached until mix.exs/mix.lock change)
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

# Compile dependencies
RUN mix deps.compile

# Install JS dependencies (layer-cached until assets/package.json changes)
COPY assets/package.json assets/package.json
RUN npm install --prefix assets

# Copy the full source (including assets/vendor/bloom/pkg/ WASM output)
COPY . .

# Build and digest frontend assets
RUN mix assets.deploy

# Compile Elixir source and build the release
RUN mix compile
RUN mix release

# Runner stage — minimal runtime image
FROM ubuntu:noble AS runner

RUN apt-get update -q && \
    apt-get install -y --no-install-recommends \
      libssl3 \
      libncurses6 \
      ca-certificates && \
    rm -rf /var/lib/apt/lists/*

ENV LANG=C.UTF-8

WORKDIR /app

# Copy the built release from the builder stage
COPY --from=builder /app/_build/prod/rel/fugue ./

# Copy the entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Ensure the data directory exists (will be overridden by volume mount)
RUN mkdir -p /data

EXPOSE 4000

ENTRYPOINT ["/docker-entrypoint.sh"]
