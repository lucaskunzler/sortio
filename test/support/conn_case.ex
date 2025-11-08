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
end
