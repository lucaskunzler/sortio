import Config

config :sortio, Sortio.Repo,
  database: "sortio_dev",
  username: "postgres",
  password: "1234",
  hostname: "localhost",
  port: 5432,
  pool_size: 10,
  show_sensitive_data_on_connection_error: true,
  stacktrace: true

config :sortio, Sortio.Auth.Guardian,
  issuer: "sortio",
  secret_key: "dev_secret_key_that_is_long_enough_for_guardian_to_work_properly_in_development"

config :logger, level: :debug

# Fast password hashing for development (use default 12 in production)
config :bcrypt_elixir, :log_rounds, 4

config :sortio, :port, 4000

config :sortio, Oban,
  repo: Sortio.Repo,
  queues: [default: 10, draws: 5],
  plugins: [
    Oban.Plugins.Pruner
  ]
