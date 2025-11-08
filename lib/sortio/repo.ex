defmodule Sortio.Repo do
  use Ecto.Repo,
    otp_app: :sortio,
    adapter: Ecto.Adapters.Postgres
end
