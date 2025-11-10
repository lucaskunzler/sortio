defmodule SortioApi.Controllers.AuthController do
  @moduledoc """
  Controller for authentication endpoints (registration, login, current user).

  Handles all authentication-related operations following RPC-style routing:
  - POST /register - Create new account
  - POST /login - Authenticate and receive JWT token
  - GET /me - Get current authenticated user
  """

  alias Sortio.Accounts
  alias Sortio.Auth.Guardian
  alias SortioApi.Helpers.ResponseHelpers
  alias SortioApi.Views.UserView

  @spec register(Plug.Conn.t()) :: Plug.Conn.t()
  @doc """
  POST /register - Register a new user account and return JWT token.
  """
  def register(conn) do
    with {:ok, params} <- validate_registration_params(conn.body_params),
         {:ok, user} <- Accounts.register_user(params),
         {:ok, token, _claims} <- Guardian.encode_and_sign(user) do
      ResponseHelpers.send_success(
        conn,
        %{
          token: token,
          user: UserView.render_user(user)
        },
        201
      )
    else
      {:error, error} ->
        handle_error(conn, error, 422)
    end
  end

  @spec login(Plug.Conn.t()) :: Plug.Conn.t()
  @doc """
  POST /login - Authenticate user and return JWT token.
  """
  def login(conn) do
    with {:ok, params} <- validate_login_params(conn.body_params),
         {:ok, user} <- Accounts.authenticate_user(params.email, params.password),
         {:ok, token, _claims} <- Guardian.encode_and_sign(user) do
      ResponseHelpers.send_success(
        conn,
        %{
          token: token,
          user: UserView.render_user(user)
        },
        200
      )
    else
      {:error, error} ->
        handle_error(conn, error, 400)
    end
  end

  @spec current_user(Plug.Conn.t()) :: Plug.Conn.t()
  @doc """
  GET /me - Get current authenticated user.
  """
  def current_user(conn) do
    user = conn.assigns.current_user

    ResponseHelpers.send_success(
      conn,
      %{user: UserView.render_user(user)},
      200
    )
  end

  # Private helpers

  defp validate_registration_params(params) do
    with {:ok, name} <- Map.fetch(params, "name"),
         {:ok, email} <- Map.fetch(params, "email"),
         {:ok, password} <- Map.fetch(params, "password") do
      {:ok, %{name: name, email: email, password: password}}
    else
      :error -> {:error, :missing_required_fields}
    end
  end

  defp validate_login_params(params) do
    with {:ok, email} <- Map.fetch(params, "email"),
         {:ok, password} <- Map.fetch(params, "password") do
      {:ok, %{email: email, password: password}}
    else
      :error -> {:error, :missing_required_fields}
    end
  end

  defp handle_error(conn, error, default_status) do
    case error do
      :invalid_credentials ->
        ResponseHelpers.send_error(conn, "Invalid email or password", 401)

      :missing_required_fields ->
        ResponseHelpers.send_error(conn, "Missing required fields", 422)

      %Ecto.Changeset{} = changeset ->
        ResponseHelpers.send_error(conn, changeset, 422)

      _other ->
        ResponseHelpers.send_error(conn, "An error occurred", default_status)
    end
  end
end
