defmodule SortioApi.RouterTest do
  use ExUnit.Case, async: true

  import SortioApi.ConnCase

  describe "GET /health" do
    test "returns 200" do
      conn = make_request("/health")
      assert conn.status == 200
      assert Jason.decode!(conn.resp_body) == %{"status" => "ok"}
    end
  end

  describe "404 route" do
    test "returns 404 for unknown routes" do
      conn = make_request("/unknown")
      assert conn.status == 404
      assert Jason.decode!(conn.resp_body) == %{"error" => "Not found"}
    end
  end
end
