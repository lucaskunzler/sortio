import Config

config :sortio,
  ecto_repos: [Sortio.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

config :sortio, Sortio.Repo,
  migration_primary_key: [type: :binary_id],
  migration_timestamps: [type: :utc_datetime]

import_config "#{config_env()}.exs"
