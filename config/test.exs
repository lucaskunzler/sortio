import Config

config :sortio, Sortio.Repo,
  database: "sortio_test#{System.get_env("MIX_TEST_PARTITION")}",
  username: "postgres",
  password: "1234",
  hostname: "localhost",
  port: 5432,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :sortio, Sortio.Guardian,
  issuer: "sortio",
  secret_key: "your-secret-key-here"

config :logger, level: :warning

config :bcrypt_elixir, :log_rounds, 4

config :sortio, port: 4001
