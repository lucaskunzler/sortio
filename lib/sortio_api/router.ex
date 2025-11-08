defmodule SortioApi.Router do
  use Plug.Router

  alias Sortio.Accounts
  alias SortioApi.Helpers.ResponseHelpers

  import ResponseHelpers

  plug(Plug.Logger)
  plug(:match)

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason
  )

  plug(:dispatch)

  get "/health" do
    send_json(conn, 200, %{"status" => "ok"})
  end

  post "/users/" do
    with {:ok, params} <- validate_user_params(conn.body_params),
         {:ok, user} <- Accounts.register_user(params) do
      send_success(conn, %{"user" => format_user(user)}, 201)
    else
      {:error, error} -> send_error(conn, error, 422)
    end
  end

  match _ do
    send_json(conn, 404, %{"error" => "Not found"})
  end

  defp validate_user_params(params) do
    with {:ok, name} <- Map.fetch(params, "name"),
         {:ok, email} <- Map.fetch(params, "email"),
         {:ok, password} <- Map.fetch(params, "password") do
      {:ok, %{name: name, email: email, password: password}}
    else
      :error -> {:error, "Missing required fields: name, email, password"}
    end
  end

  defp format_user(user) do
    %{
      id: user.id,
      name: user.name,
      email: user.email,
      inserted_at: user.inserted_at
    }
  end
end
