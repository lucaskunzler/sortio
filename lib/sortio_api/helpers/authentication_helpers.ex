defmodule SortioApi.Helpers.AuthenticationHelpers do
  @moduledoc """
  Helper functions for authentication in controllers.
  """

  @spec with_authentication(Plug.Conn.t()) :: Plug.Conn.t()
  @doc """
  Authenticates the request and returns the conn.
  Halts connection if authentication fails.
  """
  def with_authentication(conn) do
    SortioApi.Plugs.Authenticate.call(conn, [])
  end
end
