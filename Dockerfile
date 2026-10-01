# Build stage
# Keep in step with .tool-versions and .github/workflows/ci.yml.
FROM hexpm/elixir:1.20.4-erlang-29.1-alpine-3.24.2 AS builder

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

# Runner stage: minimal runtime image
# Same Alpine as the builder, so the release links against the same libs.
FROM alpine:3.24.2 AS runner

# lksctp-tools: OTP 29 warns at boot when libsctp is missing, though nothing
# here uses SCTP.
RUN apk add --no-cache openssl ncurses-libs ca-certificates libstdc++ lksctp-tools

ENV LANG=C.UTF-8

WORKDIR /app

# Copy the built release from the builder stage
COPY --from=builder /app/_build/prod/rel/fugue ./

# Copy the entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 4000

ENTRYPOINT ["/docker-entrypoint.sh"]
