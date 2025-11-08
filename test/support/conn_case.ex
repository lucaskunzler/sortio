defmodule SortioApi.ConnCase do
  @moduledoc """
  Test helpers for making HTTP requests to the router
  """

  import Plug.Test
  import Plug.Conn

  def make_request(path, method \\ :get, body \\ nil) do
    opts = SortioApi.Router.init([])

    conn(method, path, body)
    |> put_req_header("content-type", "application/json")
    |> SortioApi.Router.call(opts)
  end

  def make_authenticated_request(path, method \\ :get, token, body \\ nil) do
    opts = SortioApi.Router.init([])

    conn(method, path, body)
    |> put_req_header("content-type", "application/json")
    |> put_req_header("authorization", "Bearer #{token}")
    |> SortioApi.Router.call(opts)
  end
end
