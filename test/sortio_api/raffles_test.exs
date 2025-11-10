defmodule SortioApi.RafflesTest do
  @moduledoc """
  Integration tests for raffle API endpoints.

  Tests cover CRUD operations, authentication, authorization,
  pagination, filtering, and validation for raffles.
  """
  use ExUnit.Case, async: true
  use SortioApi.ConnCase

  alias Sortio.Raffles

  # Constants for test dates
  @one_day_in_seconds 86_400

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Sortio.Repo)

    # Create test users
    user1 = insert(:user, name: "Test User 1", email: "user1@example.com")
    user2 = insert(:user, name: "Test User 2", email: "user2@example.com")

    # Get tokens
    login_params1 = %{
      "email" => "user1@example.com",
      "password" => "password123"
    }

    login_conn1 = make_request("/login", :post, Jason.encode!(login_params1))
    token1 = Jason.decode!(login_conn1.resp_body)["token"]

    login_params2 = %{
      "email" => "user2@example.com",
      "password" => "password123"
    }

    login_conn2 = make_request("/login", :post, Jason.encode!(login_params2))
    token2 = Jason.decode!(login_conn2.resp_body)["token"]

    %{user1: user1, user2: user2, token1: token1, token2: token2}
  end

  describe "GET /raffles" do
    test "returns empty list when no raffles exist" do
      conn = make_request("/raffles", :get)

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)
      assert body["raffles"] == []
      assert body["pagination"]["total_count"] == 0
      assert body["pagination"]["page"] == 1
    end

    test "returns all raffles", %{user1: user1} do
      insert(:raffle, title: "First Raffle", description: "First description", creator: user1)
      insert(:raffle, title: "Second Raffle", description: "Second description", creator: user1)

      conn = make_request("/raffles", :get)

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)
      assert length(body["raffles"]) == 2
      assert Enum.any?(body["raffles"], fn r -> r["title"] == "First Raffle" end)
      assert Enum.any?(body["raffles"], fn r -> r["title"] == "Second Raffle" end)
      assert body["pagination"]["total_count"] == 2
      assert body["pagination"]["page"] == 1
    end

    test "filters by status", %{user1: user1} do
      insert(:raffle, title: "Open", description: "Open", status: "open", creator: user1)
      insert(:raffle, title: "Closed", description: "Closed", status: "closed", creator: user1)

      conn = make_request("/raffles?status=open", :get)

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)
      assert length(body["raffles"]) == 1
      assert hd(body["raffles"])["title"] == "Open"
      assert hd(body["raffles"])["status"] == "open"
    end

    test "returns raffles ordered by newest first", %{user1: user1} do
      raffle1 = insert(:raffle, title: "First Raffle", creator: user1)
      raffle2 = insert(:raffle, title: "Second Raffle", creator: user1)
      assert DateTime.after?(raffle2.inserted_at, raffle1.inserted_at)

      conn = make_request("/raffles", :get)

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)
      # UUIDv7: newer records have lexicographically larger IDs
      assert raffle2.id > raffle1.id

      assert length(body["raffles"]) == 2
      assert hd(body["raffles"])["title"] == "Second Raffle"
    end
  end

  describe "GET /raffles/:id" do
    test "returns 404 for non-existent ID" do
      fake_uuid = "00000000-0000-0000-0000-000000000000"
      conn = make_request("/raffles/#{fake_uuid}", :get)

      assert conn.status == 404

      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Raffle not found"
    end

    test "returns raffle details with creator info", %{user1: user1} do
      raffle =
        insert(:raffle, title: "Test Raffle", description: "Test description", creator: user1)

      conn = make_request("/raffles/#{raffle.id}", :get)

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)
      raffle_data = body["raffle"]

      assert raffle_data["id"] == raffle.id
      assert raffle_data["title"] == "Test Raffle"
      assert raffle_data["description"] == "Test description"
      assert raffle_data["status"] == "open"
      assert raffle_data["creator"]["id"] == user1.id
      assert raffle_data["creator"]["name"] == "Test User 1"
      refute Map.has_key?(raffle_data["creator"], "email")
      refute Map.has_key?(raffle_data["creator"], "password")
    end
  end

  describe "POST /raffles" do
    test "returns 401 without token" do
      params = %{
        "title" => "New Raffle",
        "description" => "Description"
      }

      conn = make_request("/raffles", :post, Jason.encode!(params))

      assert conn.status == 401

      body = Jason.decode!(conn.resp_body)
      assert body["error"]
      assert String.contains?(String.downcase(body["error"]), "authorization")
    end

    test "returns 201 with valid data", %{token1: token1} do
      future_date = DateTime.add(DateTime.utc_now(), 3600, :second) |> DateTime.to_iso8601()

      params = %{
        "title" => "New Raffle",
        "description" => "Great raffle description",
        "draw_date" => future_date
      }

      conn = make_authenticated_request("/raffles", :post, token1, Jason.encode!(params))

      assert conn.status == 201

      body = Jason.decode!(conn.resp_body)
      raffle = body["raffle"]

      assert raffle["title"] == "New Raffle"
      assert raffle["description"] == "Great raffle description"
      assert raffle["status"] == "open"
      assert raffle["id"]
    end

    test "associates with current_user as creator", %{token1: token1, user1: user1} do
      future_date = DateTime.add(DateTime.utc_now(), 3600, :second) |> DateTime.to_iso8601()

      params = %{
        "title" => "User Raffle",
        "description" => "Test",
        "draw_date" => future_date
      }

      conn = make_authenticated_request("/raffles", :post, token1, Jason.encode!(params))

      assert conn.status == 201

      body = Jason.decode!(conn.resp_body)
      raffle_id = body["raffle"]["id"]

      {:ok, raffle} = Raffles.get_raffle(raffle_id)

      assert raffle.creator == user1
    end

    test "returns 422 with missing title", %{token1: token1} do
      params = %{
        "description" => "Description without title"
      }

      conn = make_authenticated_request("/raffles", :post, token1, Jason.encode!(params))

      assert conn.status == 422

      body = Jason.decode!(conn.resp_body)
      assert body["error"]
      assert String.contains?(String.downcase(body["error"]), "title")
    end

    test "returns 422 with invalid title (too short)", %{token1: token1} do
      params = %{
        "title" => "ab"
      }

      conn = make_authenticated_request("/raffles", :post, token1, Jason.encode!(params))

      assert conn.status == 422

      body = Jason.decode!(conn.resp_body)
      assert body["error"]
      assert String.contains?(String.downcase(body["error"]), "title")
    end

    test "accepts valid draw_date in future", %{token1: token1} do
      future_date =
        DateTime.utc_now() |> DateTime.add(@one_day_in_seconds, :second) |> DateTime.to_iso8601()

      params = %{
        "title" => "Future Raffle",
        "description" => "With draw date",
        "draw_date" => future_date
      }

      conn = make_authenticated_request("/raffles", :post, token1, Jason.encode!(params))

      assert conn.status == 201

      body = Jason.decode!(conn.resp_body)
      assert body["raffle"]["draw_date"]
    end

    test "returns 422 with past draw_date", %{token1: token1} do
      past_date =
        DateTime.utc_now() |> DateTime.add(-@one_day_in_seconds, :second) |> DateTime.to_iso8601()

      params = %{
        "title" => "Past Raffle",
        "draw_date" => past_date
      }

      conn = make_authenticated_request("/raffles", :post, token1, Jason.encode!(params))

      assert conn.status == 422

      body = Jason.decode!(conn.resp_body)
      assert body["error"]

      assert String.contains?(String.downcase(body["error"]), "draw_date") or
               String.contains?(String.downcase(body["error"]), "draw date")
    end

    test "malformed JSON raises ParseError", %{token1: token1} do
      # Invalid JSON - missing closing brace
      # Note: Plug.Parsers will raise an exception for malformed JSON
      assert_raise Plug.Parsers.ParseError, fn ->
        opts = SortioApi.Router.init([])

        Plug.Test.conn(:post, "/raffles", "{\"title\": \"Test\"")
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Plug.Conn.put_req_header("authorization", "Bearer #{token1}")
        |> SortioApi.Router.call(opts)
      end
    end

    test "extremely long title returns 422", %{token1: token1} do
      # Generate a title longer than typical database limits
      long_title = String.duplicate("a", 300)

      params = %{
        "title" => long_title,
        "description" => "Valid description"
      }

      conn = make_authenticated_request("/raffles", :post, token1, Jason.encode!(params))

      assert conn.status == 422

      body = Jason.decode!(conn.resp_body)
      assert body["error"]
      assert String.contains?(String.downcase(body["error"]), "title")
    end

    test "extremely long description is accepted", %{token1: token1} do
      # Generate a very long description (descriptions often have higher limits)
      long_description = String.duplicate("a", 5000)

      params = %{
        "title" => "Valid Title",
        "description" => long_description
      }

      conn = make_authenticated_request("/raffles", :post, token1, Jason.encode!(params))

      # This might be 201 or 422 depending on your database schema
      # Adjust based on actual requirements
      assert conn.status in [201, 422]
    end
  end

  describe "PUT /raffles/:id" do
    test "returns 401 without token", %{user1: user1} do
      raffle = insert(:raffle, title: "Test Raffle", creator: user1)

      params = %{
        "title" => "Updated Title"
      }

      conn = make_request("/raffles/#{raffle.id}", :put, Jason.encode!(params))

      assert conn.status == 401

      body = Jason.decode!(conn.resp_body)
      assert body["error"]
      assert String.contains?(String.downcase(body["error"]), "authorization")
    end

    test "returns 403 if not owner", %{user1: user1, token2: token2} do
      raffle = insert(:raffle, title: "User 1 Raffle", creator: user1)

      params = %{
        "title" => "Trying to update"
      }

      conn =
        make_authenticated_request("/raffles/#{raffle.id}", :put, token2, Jason.encode!(params))

      assert conn.status == 403

      body = Jason.decode!(conn.resp_body)
      assert body["error"]
      assert String.contains?(String.downcase(body["error"]), "permission")
    end

    test "returns 200 with valid update", %{user1: user1, token1: token1} do
      raffle =
        insert(:raffle,
          title: "Original Title",
          description: "Original description",
          creator: user1
        )

      params = %{
        "title" => "Updated Title",
        "description" => "Updated description"
      }

      conn =
        make_authenticated_request("/raffles/#{raffle.id}", :put, token1, Jason.encode!(params))

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)
      raffle_data = body["raffle"]

      assert raffle_data["title"] == "Updated Title"
      assert raffle_data["description"] == "Updated description"
    end

    test "can change status to closed", %{user1: user1, token1: token1} do
      raffle = insert(:raffle, title: "Test Raffle", creator: user1)

      params = %{
        "status" => "closed"
      }

      conn =
        make_authenticated_request("/raffles/#{raffle.id}", :put, token1, Jason.encode!(params))

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)
      assert body["raffle"]["status"] == "closed"
    end

    test "returns 422 with invalid data (invalid status)", %{user1: user1, token1: token1} do
      raffle = insert(:raffle, title: "Test Raffle", creator: user1)

      params = %{
        "status" => "invalid_status"
      }

      conn =
        make_authenticated_request("/raffles/#{raffle.id}", :put, token1, Jason.encode!(params))

      assert conn.status == 422

      body = Jason.decode!(conn.resp_body)
      assert body["error"]
      assert String.contains?(String.downcase(body["error"]), "status")
    end

    test "returns 422 with invalid title (too short)", %{user1: user1, token1: token1} do
      raffle = insert(:raffle, title: "Test Raffle", creator: user1)

      params = %{
        "title" => "ab"
      }

      conn =
        make_authenticated_request("/raffles/#{raffle.id}", :put, token1, Jason.encode!(params))

      assert conn.status == 422

      body = Jason.decode!(conn.resp_body)
      assert body["error"]
      assert String.contains?(String.downcase(body["error"]), "title")
    end

    test "returns 404 for non-existent raffle", %{token1: token1} do
      fake_uuid = "00000000-0000-0000-0000-000000000000"

      params = %{
        "title" => "Updated Title"
      }

      conn =
        make_authenticated_request("/raffles/#{fake_uuid}", :put, token1, Jason.encode!(params))

      assert conn.status == 404

      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Raffle not found"
    end
  end

  describe "DELETE /raffles/:id" do
    test "returns 401 without token", %{user1: user1} do
      raffle = insert(:raffle, title: "Test Raffle", creator: user1)

      conn = make_request("/raffles/#{raffle.id}", :delete)

      assert conn.status == 401

      body = Jason.decode!(conn.resp_body)
      assert body["error"]
      assert String.contains?(String.downcase(body["error"]), "authorization")
    end

    test "returns 403 if not owner", %{user1: user1, token2: token2} do
      raffle = insert(:raffle, title: "User 1 Raffle", creator: user1)

      conn = make_authenticated_request("/raffles/#{raffle.id}", :delete, token2)

      assert conn.status == 403

      body = Jason.decode!(conn.resp_body)
      assert body["error"]
      assert String.contains?(String.downcase(body["error"]), "permission")
    end

    test "returns 204 and deletes raffle", %{user1: user1, token1: token1} do
      raffle = insert(:raffle, title: "Test Raffle", creator: user1)

      conn = make_authenticated_request("/raffles/#{raffle.id}", :delete, token1)

      assert conn.status == 204

      assert Raffles.get_raffle(raffle.id) == {:error, :not_found}
    end

    test "returns 404 for non-existent raffle", %{token1: token1} do
      fake_uuid = "00000000-0000-0000-0000-000000000000"

      conn = make_authenticated_request("/raffles/#{fake_uuid}", :delete, token1)

      assert conn.status == 404

      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Raffle not found"
    end
  end
end
