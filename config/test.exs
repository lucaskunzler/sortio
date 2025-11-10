import Config

config :sortio, Sortio.Repo,
  database: "sortio_test#{System.get_env("MIX_TEST_PARTITION")}",
  username: "postgres",
  password: "1234",
  hostname: "localhost",
  port: 5432,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :sortio, Sortio.Auth.Guardian,
  issuer: "sortio",
  secret_key: "test_secret_key_that_is_long_enough_for_guardian_to_work_properly_in_tests"

config :logger, level: :none

config :bcrypt_elixir, :log_rounds, 4

config :sortio, port: 4001

config :sortio, Oban,
  repo: Sortio.Repo,
  testing: :manual,
  queues: false,
  plugins: false
