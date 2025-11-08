defmodule SortioApi.Router do
  use Plug.Router

  import SortioApi.Helpers.ResponseHelpers

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

  match _ do
    send_json(conn, 404, %{"error" => "Not found"})
  end
end
