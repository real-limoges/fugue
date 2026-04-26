import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :fugue, FugueWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "V+BfH4Lsk46W+lo6pb6pnQBeC5s2dCapdxsMu8rFkcJtWBtPtrXpJzZnwwtj/xAI",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Skip CozoDB in test — no tests require it yet
config :fugue, start_db: false

# Use a controlled fixture directory so blog tests don't depend on real posts.
config :fugue, blog_dir: "test/support/fixtures/blog"

# Stub Ish HTTP calls with Req.Test. Tests use `Req.Test.stub(Fugue.Ish, fn)`
# to define responses per-test. Any unstubbed call fails loudly.
config :fugue, Fugue.Ish,
  url: "http://ish.test",
  gcp_auth: false,
  plug: {Req.Test, Fugue.Ish}
