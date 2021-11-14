import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :cx_new, CxNewWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "FotfBM55xlVdBTJZmZph70qX+1kfl5kuuRBcKJ9gQjU7BUBYpWU2Yr+0uMcNFce0",
  server: false

# In test we don't send emails.
config :cx_new, CxNew.Mailer, adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
