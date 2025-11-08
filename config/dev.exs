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

config :sortio, Sortio.Guardian,
  issuer: "sortio",
  secret_key: "your-secret-key-here"

config :logger, level: :debug

# Fast password hashing for development (use default 12 in production)
config :bcrypt_elixir, :log_rounds, 4

config :sortio, :port, 4000
