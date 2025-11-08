defmodule SortioApi.Router do
  use Plug.Router

  alias Sortio.Accounts
  alias Sortio.Auth.Guardian
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

  post "/users" do
    with {:ok, params} <- validate_user_params(conn.body_params),
         {:ok, user} <- Accounts.register_user(params) do
      send_success(conn, %{"user" => format_user(user)}, 201)
    else
      {:error, error} -> send_error(conn, error, 422)
    end
  end

  post "/login" do
    with {:ok, params} <- validate_login_params(conn.body_params),
         {:ok, user} <- Accounts.authenticate_user(params.email, params.password),
         {:ok, token, _claims} <- Guardian.encode_and_sign(user) do
      send_success(
        conn,
        %{
          "token" => token,
          "user" => format_user(user)
        },
        200
      )
    else
      {:error, :invalid_credentials} ->
        send_error(conn, "Invalid email or password", 401)

      {:error, error} ->
        send_error(conn, error, 400)
    end
  end

  get "/me" do
    case authenticate(conn) do
      %{halted: true} = conn ->
        conn

      conn ->
        user = conn.assigns.current_user
        send_success(conn, %{"user" => format_user(user)}, 200)
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

  defp validate_login_params(params) do
    with {:ok, email} <- Map.fetch(params, "email"),
         {:ok, password} <- Map.fetch(params, "password") do
      {:ok, %{email: email, password: password}}
    else
      :error -> {:error, "Missing required fields: email, password"}
    end
  end

  defp authenticate(conn) do
    SortioApi.Plugs.Authenticate.call(conn, [])
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
