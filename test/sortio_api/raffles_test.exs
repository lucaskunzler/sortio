defmodule SortioApi.RafflesTest do
  @moduledoc """
  Integration tests for raffle API endpoints.

  Tests cover CRUD operations, authentication, authorization,
  pagination, filtering, and validation for raffles.
  """
  use ExUnit.Case, async: false

  import SortioApi.ConnCase

  alias Sortio.Accounts
  alias Sortio.Raffles

  # Constants for test timing and dates
  @timestamp_precision_delay_ms 1100
  @one_day_in_seconds 86_400

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Sortio.Repo)

    # Create test users
    {:ok, user1} =
      Accounts.register_user(%{
        name: "Test User 1",
        email: "user1@example.com",
        password: "password123"
      })

    {:ok, user2} =
      Accounts.register_user(%{
        name: "Test User 2",
        email: "user2@example.com",
        password: "password123"
      })

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
      # Create some raffles
      {:ok, _raffle1} =
        Raffles.create_raffle(
          %{title: "First Raffle", description: "First description"},
          user1.id
        )

      {:ok, _raffle2} =
        Raffles.create_raffle(
          %{title: "Second Raffle", description: "Second description"},
          user1.id
        )

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
      # Create raffles with different statuses
      {:ok, _raffle1} =
        Raffles.create_raffle(
          %{title: "Open Raffle", description: "Open"},
          user1.id
        )

      {:ok, raffle2} =
        Raffles.create_raffle(
          %{title: "Closed Raffle", description: "Closed"},
          user1.id
        )

      # Update raffle2 to closed status
      Raffles.update_raffle(raffle2, %{status: "closed"})

      conn = make_request("/raffles?status=open", :get)

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)
      assert length(body["raffles"]) == 1
      assert hd(body["raffles"])["title"] == "Open Raffle"
      assert hd(body["raffles"])["status"] == "open"
    end

    test "returns raffles ordered by newest first", %{user1: user1} do
      {:ok, raffle1} =
        Raffles.create_raffle(
          %{title: "First Raffle"},
          user1.id
        )

      # Delay to ensure different timestamps (timestamps are second-precision)
      Process.sleep(@timestamp_precision_delay_ms)

      {:ok, raffle2} =
        Raffles.create_raffle(
          %{title: "Second Raffle"},
          user1.id
        )

      # Verify timestamps are different
      assert NaiveDateTime.compare(raffle2.inserted_at, raffle1.inserted_at) == :gt

      conn = make_request("/raffles", :get)

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)
      assert length(body["raffles"]) == 2
      # Newest should be first (Second Raffle was created last)
      assert hd(body["raffles"])["title"] == "Second Raffle"
      assert body["pagination"]["total_count"] == 2
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
      {:ok, raffle} =
        Raffles.create_raffle(
          %{title: "Test Raffle", description: "Test description"},
          user1.id
        )

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
      assert body["error"] =~ "authorization"
    end

    test "returns 201 with valid data", %{token1: token1} do
      params = %{
        "title" => "New Raffle",
        "description" => "Great raffle description"
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
      params = %{
        "title" => "User Raffle",
        "description" => "Test"
      }

      conn = make_authenticated_request("/raffles", :post, token1, Jason.encode!(params))

      assert conn.status == 201

      body = Jason.decode!(conn.resp_body)
      raffle_id = body["raffle"]["id"]

      # Verify in database
      raffle = Raffles.get_raffle(raffle_id)
      assert raffle.creator_id == user1.id
    end

    test "returns 422 with missing title", %{token1: token1} do
      params = %{
        "description" => "Description without title"
      }

      conn = make_authenticated_request("/raffles", :post, token1, Jason.encode!(params))

      assert conn.status == 422

      body = Jason.decode!(conn.resp_body)
      assert body["error"] =~ "title"
    end

    test "returns 422 with invalid title (too short)", %{token1: token1} do
      params = %{
        "title" => "ab"
      }

      conn = make_authenticated_request("/raffles", :post, token1, Jason.encode!(params))

      assert conn.status == 422

      body = Jason.decode!(conn.resp_body)
      assert body["error"] =~ "title"
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
      assert body["error"] =~ "draw_date"
    end
  end

  describe "PUT /raffles/:id" do
    test "returns 401 without token", %{user1: user1} do
      {:ok, raffle} = Raffles.create_raffle(%{title: "Test Raffle"}, user1.id)

      params = %{
        "title" => "Updated Title"
      }

      conn = make_request("/raffles/#{raffle.id}", :put, Jason.encode!(params))

      assert conn.status == 401

      body = Jason.decode!(conn.resp_body)
      assert body["error"] =~ "authorization"
    end

    test "returns 403 if not owner", %{user1: user1, token2: token2} do
      {:ok, raffle} = Raffles.create_raffle(%{title: "User 1 Raffle"}, user1.id)

      params = %{
        "title" => "Trying to update"
      }

      conn =
        make_authenticated_request("/raffles/#{raffle.id}", :put, token2, Jason.encode!(params))

      assert conn.status == 403

      body = Jason.decode!(conn.resp_body)
      assert body["error"] =~ "permission"
    end

    test "returns 200 with valid update", %{user1: user1, token1: token1} do
      {:ok, raffle} =
        Raffles.create_raffle(
          %{title: "Original Title", description: "Original description"},
          user1.id
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
      {:ok, raffle} = Raffles.create_raffle(%{title: "Test Raffle"}, user1.id)

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
      {:ok, raffle} = Raffles.create_raffle(%{title: "Test Raffle"}, user1.id)

      params = %{
        "status" => "invalid_status"
      }

      conn =
        make_authenticated_request("/raffles/#{raffle.id}", :put, token1, Jason.encode!(params))

      assert conn.status == 422

      body = Jason.decode!(conn.resp_body)
      assert body["error"] =~ "status"
    end

    test "returns 422 with invalid title (too short)", %{user1: user1, token1: token1} do
      {:ok, raffle} = Raffles.create_raffle(%{title: "Test Raffle"}, user1.id)

      params = %{
        "title" => "ab"
      }

      conn =
        make_authenticated_request("/raffles/#{raffle.id}", :put, token1, Jason.encode!(params))

      assert conn.status == 422

      body = Jason.decode!(conn.resp_body)
      assert body["error"] =~ "title"
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
      {:ok, raffle} = Raffles.create_raffle(%{title: "Test Raffle"}, user1.id)

      conn = make_request("/raffles/#{raffle.id}", :delete)

      assert conn.status == 401

      body = Jason.decode!(conn.resp_body)
      assert body["error"] =~ "authorization"
    end

    test "returns 403 if not owner", %{user1: user1, token2: token2} do
      {:ok, raffle} = Raffles.create_raffle(%{title: "User 1 Raffle"}, user1.id)

      conn = make_authenticated_request("/raffles/#{raffle.id}", :delete, token2)

      assert conn.status == 403

      body = Jason.decode!(conn.resp_body)
      assert body["error"] =~ "permission"
    end

    test "returns 204 and deletes raffle", %{user1: user1, token1: token1} do
      {:ok, raffle} = Raffles.create_raffle(%{title: "Test Raffle"}, user1.id)

      conn = make_authenticated_request("/raffles/#{raffle.id}", :delete, token1)

      assert conn.status == 204

      # Verify raffle is deleted
      assert Raffles.get_raffle(raffle.id) == nil
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
