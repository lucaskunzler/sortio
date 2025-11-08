defmodule SortioApi.Plugs.Authenticate do
  @moduledoc """
  Plug to authenticate requests using JWT tokens.
  Expects the Authorization header with format: Bearer <token>
  """
  require Logger
  import Plug.Conn

  alias Sortio.Auth.Guardian
  alias SortioApi.Helpers.ResponseHelpers

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        verify_token(conn, token)

      _ ->
        Logger.warning("Authentication failed - missing or invalid authorization header",
          path: conn.request_path,
          method: conn.method
        )

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
            Logger.debug("Token validated successfully",
              user_id: user.id,
              path: conn.request_path
            )

            assign(conn, :current_user, user)

          {:error, reason} ->
            Logger.warning("Authentication failed - invalid token claims",
              reason: reason,
              path: conn.request_path
            )

            conn
            |> ResponseHelpers.send_error("Invalid token", 401)
            |> halt()
        end

      {:error, reason} ->
        Logger.warning("Authentication failed - token decode failed",
          reason: reason,
          path: conn.request_path
        )

        conn
        |> ResponseHelpers.send_error("Invalid or expired token", 401)
        |> halt()
    end
  end
end
