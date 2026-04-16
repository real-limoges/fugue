# Build stage
FROM hexpm/elixir:1.19.5-erlang-26.2.3-alpine-3.23.4 AS builder

# Install system dependencies needed for compilation and assets (Node.js)
RUN apk add --no-cache build-base nodejs npm git ca-certificates

WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod

# Copy the full source
COPY . .

RUN mix deps.get --only prod
RUN npm install --prefix assets
RUN mix compile

RUN mix assets.deploy
RUN mix release

# Runner stage — minimal runtime image
FROM alpine:3.23 AS runner

RUN apk add --no-cache openssl ncurses-libs ca-certificates

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
