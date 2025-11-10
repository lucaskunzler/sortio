import Config

# Runtime configuration for production environment
# This file is executed on application startup for all environments

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: postgres://USER:PASS@HOST/DATABASE
      """

  config :sortio, Sortio.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # Increase timeout for production loads
    timeout: 15_000,
    # SSL configuration for production databases
    ssl: true

  guardian_secret =
    System.get_env("GUARDIAN_SECRET_KEY") ||
      raise """
      environment variable GUARDIAN_SECRET_KEY is missing.
      You can generate one by calling: mix guardian.gen.secret
      """

  config :sortio, Sortio.Auth.Guardian, secret_key: guardian_secret
end
