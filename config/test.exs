import Config

config :quadblockquiz, game_seed: {1, 2, 3}

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :quadblockquiz, QuadblockquizWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "KVnBS6z5N9Mmrwt0+KO2YbTLwc3aQEipaxht/E8RceUL6W7MPEJqaSBjhmu1mpOz",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
