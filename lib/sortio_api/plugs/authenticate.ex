defmodule SortioApi.Plugs.Authenticate do
  @moduledoc """
  Plug to authenticate requests using JWT tokens.
  Expects the Authorization header with format: Bearer <token>
  """
  import Plug.Conn

  alias Sortio.Auth.Guardian
  alias SortioApi.Helpers.ResponseHelpers

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        verify_token(conn, token)

      _ ->
        conn
        |> ResponseHelpers.send_error("Missing or invalid authorization header", 401)
        |> halt()
    end
  end

  defp verify_token(conn, token) do
    case Guardian.decode_and_verify(token) do
      {:ok, claims} ->
        case Guardian.resource_from_claims(claims) do
          {:ok, user} ->
            assign(conn, :current_user, user)

          {:error, _reason} ->
            conn
            |> ResponseHelpers.send_error("Invalid token", 401)
            |> halt()
        end

      {:error, _reason} ->
        conn
        |> ResponseHelpers.send_error("Invalid or expired token", 401)
        |> halt()
    end
  end
end
