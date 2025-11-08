import Config

config :sortio,
  ecto_repos: [Sortio.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

config :sortio, Sortio.Repo,
  migration_primary_key: [type: :binary_id],
  migration_timestamps: [type: :utc_datetime]

# Logger configuration - IMPORTANT: Do not log PII (emails, names, etc.)
# Only log non-sensitive identifiers like user_id (UUID)
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:user_id, :path, :method, :reason, :errors]

import_config "#{config_env()}.exs"
