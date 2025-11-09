defmodule SortioApi.Router do
  @moduledoc """
  Main router for Sortio API.

  Routes authentication and resource requests to appropriate controllers.
  Follows hybrid approach:
  - Auth endpoints: RPC-style (/register, /login, /me)
  - Resources: REST-style (/raffles)
  """
  use Plug.Router

  alias SortioApi.Controllers.{AuthController, RaffleController}
  alias SortioApi.Helpers.{ResponseHelpers, AuthenticationHelpers}

  plug(Plug.Logger)
  plug(:match)

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason
  )

  plug(:dispatch)

  # Health check
  get "/health" do
    ResponseHelpers.send_json(conn, 200, %{"status" => "ok"})
  end

  # Authentication endpoints (RPC-style)
  post "/register" do
    AuthController.register(conn)
  end

  post "/login" do
    AuthController.login(conn)
  end

  get "/me" do
    conn
    |> AuthenticationHelpers.with_authentication()
    |> case do
      %{halted: true} = conn -> conn
      conn -> AuthController.current_user(conn)
    end
  end

  # Raffle endpoints - Public
  get "/raffles" do
    RaffleController.index(conn)
  end

  get "/raffles/:id" do
    RaffleController.show(conn, id)
  end

  # Raffle endpoints - Authenticated
  post "/raffles" do
    conn
    |> AuthenticationHelpers.with_authentication()
    |> case do
      %{halted: true} = conn -> conn
      conn -> RaffleController.create(conn)
    end
  end

  put "/raffles/:id" do
    conn
    |> AuthenticationHelpers.with_authentication()
    |> case do
      %{halted: true} = conn -> conn
      conn -> RaffleController.update(conn, id)
    end
  end

  delete "/raffles/:id" do
    conn
    |> AuthenticationHelpers.with_authentication()
    |> case do
      %{halted: true} = conn -> conn
      conn -> RaffleController.delete(conn, id)
    end
  end

  # 404 handler
  match _ do
    ResponseHelpers.send_json(conn, 404, %{"error" => "Not found"})
  end
end
