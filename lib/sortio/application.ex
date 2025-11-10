defmodule Sortio.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    port = Application.get_env(:sortio, :port, 4000)

    children = [
      Sortio.Repo,
      {Oban, Application.fetch_env!(:sortio, Oban)},
      {Plug.Cowboy, scheme: :http, plug: SortioApi.Router, options: [port: port]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Sortio.Supervisor]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      Logger.info("Server listening on http://localhost:#{port}")
      {:ok, pid}
    end
  end
end
