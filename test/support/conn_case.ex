defmodule SortioApi.ConnCase do
  @moduledoc """
  Test helpers for making HTTP requests to the router
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Plug.Test
      import Plug.Conn
      import Sortio.Factory
      import SortioApi.ConnCase
    end
  end

  def make_request(path, method \\ :get, body \\ nil) do
    opts = SortioApi.Router.init([])

    Plug.Test.conn(method, path, body)
    |> Plug.Conn.put_req_header("content-type", "application/json")
    |> SortioApi.Router.call(opts)
  end

  def make_authenticated_request(path, method \\ :get, token, body \\ nil) do
    opts = SortioApi.Router.init([])

    Plug.Test.conn(method, path, body)
    |> Plug.Conn.put_req_header("content-type", "application/json")
    |> Plug.Conn.put_req_header("authorization", "Bearer #{token}")
    |> SortioApi.Router.call(opts)
  end
end
