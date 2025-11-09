defmodule SortioApi.ParticipantsTest do
  @moduledoc """
  Integration tests for participant API endpoints.

  Tests cover joining, leaving, and listing participants,
  including authentication, authorization, and business rules.
  """
  use ExUnit.Case, async: true
  use SortioApi.ConnCase

  alias Sortio.Raffles

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Sortio.Repo)

    # Create test users
    user1 = insert(:user, name: "Test User 1", email: "user1@example.com")
    user2 = insert(:user, name: "Test User 2", email: "user2@example.com")
    user3 = insert(:user, name: "Test User 3", email: "user3@example.com")

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

    login_params3 = %{
      "email" => "user3@example.com",
      "password" => "password123"
    }

    login_conn3 = make_request("/login", :post, Jason.encode!(login_params3))
    token3 = Jason.decode!(login_conn3.resp_body)["token"]

    %{
      user1: user1,
      user2: user2,
      user3: user3,
      token1: token1,
      token2: token2,
      token3: token3
    }
  end

  describe "POST /raffles/:id/join" do
    test "returns 401 without authentication token", %{user1: user1} do
      raffle = insert(:raffle, creator: user1)

      conn = make_request("/raffles/#{raffle.id}/join", :post)

      assert conn.status == 401

      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Missing or invalid authorization header"
    end

    test "returns 201 and creates participation with valid token", %{user1: user1, token2: token2} do
      raffle = insert(:raffle, creator: user1)

      conn = make_authenticated_request("/raffles/#{raffle.id}/join", :post, token2)

      assert conn.status == 201

      body = Jason.decode!(conn.resp_body)
      assert body["participant"]["raffle_id"] == raffle.id
      assert body["participant"]["id"]
      assert body["participant"]["inserted_at"]

      assert Raffles.get_participant_count(raffle.id) == 1
    end

    test "returns 422 if user already joined the raffle", %{
      user1: user1,
      token2: token2
    } do
      raffle = insert(:raffle, creator: user1)

      # First join should succeed
      conn1 = make_authenticated_request("/raffles/#{raffle.id}/join", :post, token2)
      assert conn1.status == 201

      # Second join should fail with validation error
      conn2 = make_authenticated_request("/raffles/#{raffle.id}/join", :post, token2)
      assert conn2.status == 422

      body = Jason.decode!(conn2.resp_body)
      # The error message should indicate duplicate entry
      assert body["error"]
      assert String.contains?(body["error"], "already joined")
    end

    test "creator can join their own raffle", %{user1: user1, token1: token1} do
      raffle = insert(:raffle, creator: user1)

      conn = make_authenticated_request("/raffles/#{raffle.id}/join", :post, token1)

      assert conn.status == 201

      body = Jason.decode!(conn.resp_body)
      assert body["participant"]["raffle_id"] == raffle.id
    end

    test "returns 404 if raffle doesn't exist", %{token1: token1} do
      fake_uuid = "018e1234-5678-7abc-def0-123456789012"

      conn = make_authenticated_request("/raffles/#{fake_uuid}/join", :post, token1)

      assert conn.status == 404

      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Raffle not found"
    end

    test "returns 400 with invalid UUID format", %{token1: token1} do
      conn = make_authenticated_request("/raffles/invalid-uuid/join", :post, token1)

      assert conn.status == 400

      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Invalid raffle ID format"
    end

    test "returns 422 when trying to join closed raffle", %{user1: user1, token2: token2} do
      raffle = insert(:raffle, creator: user1, status: "closed")

      conn = make_authenticated_request("/raffles/#{raffle.id}/join", :post, token2)

      assert conn.status == 422

      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Cannot join a closed raffle"
    end
  end

  describe "DELETE /raffles/:id/leave" do
    test "returns 401 without authentication token", %{user1: user1} do
      raffle = insert(:raffle, creator: user1)

      conn = make_request("/raffles/#{raffle.id}/leave", :delete)

      assert conn.status == 401

      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Missing or invalid authorization header"
    end

    test "returns 204 when successfully leaving raffle", %{
      user1: user1,
      user2: user2,
      token2: token2
    } do
      raffle = insert(:raffle, creator: user1)

      # First join the raffle
      {:ok, _participant} = Raffles.join_raffle(raffle.id, user2.id)
      assert Raffles.get_participant_count(raffle.id) == 1

      # Then leave
      conn = make_authenticated_request("/raffles/#{raffle.id}/leave", :delete, token2)

      assert conn.status == 204
      assert conn.resp_body == "null"

      # Verify participation was removed
      assert Raffles.get_participant_count(raffle.id) == 0
      refute Raffles.user_participating?(raffle.id, user2.id)
    end

    test "returns 404 if user is not participating", %{user1: user1, token2: token2} do
      raffle = insert(:raffle, creator: user1)

      conn = make_authenticated_request("/raffles/#{raffle.id}/leave", :delete, token2)

      assert conn.status == 404

      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "You are not participating in this raffle"
    end

    test "returns 400 with invalid UUID format", %{token1: token1} do
      conn = make_authenticated_request("/raffles/invalid-uuid/leave", :delete, token1)

      assert conn.status == 400

      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Invalid raffle ID format"
    end

    test "returns 404 if raffle doesn't exist", %{token1: token1} do
      fake_uuid = "018e1234-5678-7abc-def0-123456789012"

      conn = make_authenticated_request("/raffles/#{fake_uuid}/leave", :delete, token1)

      assert conn.status == 404

      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "You are not participating in this raffle"
    end
  end

  describe "GET /raffles/:id/participants" do
    test "works without authentication (public endpoint)", %{user1: user1} do
      raffle = insert(:raffle, creator: user1)

      conn = make_request("/raffles/#{raffle.id}/participants", :get)

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)
      assert body["participants"] == []
      assert body["count"] == 0
    end

    test "returns empty list for raffle with no participants", %{user1: user1} do
      raffle = insert(:raffle, creator: user1)

      conn = make_request("/raffles/#{raffle.id}/participants", :get)

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)
      assert body["participants"] == []
      assert body["count"] == 0
    end

    test "returns all participants with user info", %{
      user1: user1,
      user2: user2,
      user3: user3
    } do
      raffle = insert(:raffle, creator: user1)

      # Add participants
      {:ok, _} = Raffles.join_raffle(raffle.id, user2.id)
      {:ok, _} = Raffles.join_raffle(raffle.id, user3.id)

      conn = make_request("/raffles/#{raffle.id}/participants", :get)

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)
      assert length(body["participants"]) == 2
      assert body["count"] == 2

      # Check user info is included
      participants = body["participants"]
      user_ids = Enum.map(participants, & &1["user"]["id"])
      assert user2.id in user_ids
      assert user3.id in user_ids

      # Verify user info structure
      first_participant = hd(participants)
      assert first_participant["id"]
      assert first_participant["raffle_id"] == raffle.id
      assert first_participant["user"]["id"]
      assert first_participant["user"]["name"]
      assert first_participant["inserted_at"]
    end

    test "returns participants ordered by join date (newest first)", %{
      user1: user1,
      user2: user2,
      user3: user3
    } do
      raffle = insert(:raffle, creator: user1)

      # Join in specific order
      {:ok, _participant1} = Raffles.join_raffle(raffle.id, user2.id)
      {:ok, _participant2} = Raffles.join_raffle(raffle.id, user3.id)

      conn = make_request("/raffles/#{raffle.id}/participants", :get)

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)
      participants = body["participants"]

      # Should have both participants
      assert length(participants) == 2
      user_ids = Enum.map(participants, & &1["user"]["id"])
      assert user2.id in user_ids
      assert user3.id in user_ids

      # Verify timestamps are present and in descending order (newest first)
      timestamps =
        participants
        |> Enum.map(& &1["inserted_at"])
        |> Enum.map(fn ts ->
          {:ok, naive_datetime} = NaiveDateTime.from_iso8601(ts)
          naive_datetime
        end)

      # Verify all timestamps are present
      assert length(timestamps) == 2

      # Verify they're in descending order
      sorted_desc = Enum.sort(timestamps, {:desc, NaiveDateTime})
      assert timestamps == sorted_desc
    end

    test "returns 400 with invalid UUID format" do
      conn = make_request("/raffles/invalid-uuid/participants", :get)

      assert conn.status == 400

      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Invalid raffle ID format"
    end

    test "returns empty list if raffle doesn't exist" do
      fake_uuid = "018e1234-5678-7abc-def0-123456789012"

      conn = make_request("/raffles/#{fake_uuid}/participants", :get)

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)
      assert body["participants"] == []
      assert body["count"] == 0
    end
  end

  describe "Edge cases" do
    test "user can join after leaving", %{user1: user1, token2: token2} do
      raffle = insert(:raffle, creator: user1)

      # Join
      conn1 = make_authenticated_request("/raffles/#{raffle.id}/join", :post, token2)
      assert conn1.status == 201
      assert Raffles.get_participant_count(raffle.id) == 1

      # Leave
      conn2 = make_authenticated_request("/raffles/#{raffle.id}/leave", :delete, token2)
      assert conn2.status == 204
      assert Raffles.get_participant_count(raffle.id) == 0

      # Join again
      conn3 = make_authenticated_request("/raffles/#{raffle.id}/join", :post, token2)
      assert conn3.status == 201

      body = Jason.decode!(conn3.resp_body)
      assert body["participant"]["raffle_id"] == raffle.id
      assert Raffles.get_participant_count(raffle.id) == 1
    end

    test "participant count is accurate with multiple joins and leaves", %{
      user1: user1,
      user2: user2,
      user3: user3
    } do
      raffle = insert(:raffle, creator: user1)

      # Initially 0
      assert Raffles.get_participant_count(raffle.id) == 0

      # Add 2 participants
      {:ok, _} = Raffles.join_raffle(raffle.id, user2.id)
      assert Raffles.get_participant_count(raffle.id) == 1

      {:ok, _} = Raffles.join_raffle(raffle.id, user3.id)
      assert Raffles.get_participant_count(raffle.id) == 2

      # Remove 1 participant
      {:ok, _} = Raffles.leave_raffle(raffle.id, user2.id)
      assert Raffles.get_participant_count(raffle.id) == 1

      # Verify correct participant remains
      assert Raffles.user_participating?(raffle.id, user3.id)
      refute Raffles.user_participating?(raffle.id, user2.id)
    end

    test "user_participating? returns correct status", %{user1: user1, user2: user2} do
      raffle = insert(:raffle, creator: user1)

      # Initially not participating
      refute Raffles.user_participating?(raffle.id, user2.id)

      # After joining
      {:ok, _} = Raffles.join_raffle(raffle.id, user2.id)
      assert Raffles.user_participating?(raffle.id, user2.id)

      # After leaving
      {:ok, _} = Raffles.leave_raffle(raffle.id, user2.id)
      refute Raffles.user_participating?(raffle.id, user2.id)
    end

    test "multiple users can join the same raffle", %{
      user1: user1,
      user2: user2,
      user3: user3,
      token2: token2,
      token3: token3
    } do
      raffle = insert(:raffle, creator: user1)

      # User 2 joins
      conn1 = make_authenticated_request("/raffles/#{raffle.id}/join", :post, token2)
      assert conn1.status == 201

      # User 3 joins
      conn2 = make_authenticated_request("/raffles/#{raffle.id}/join", :post, token3)
      assert conn2.status == 201

      # Verify both are participants
      assert Raffles.get_participant_count(raffle.id) == 2
      assert Raffles.user_participating?(raffle.id, user2.id)
      assert Raffles.user_participating?(raffle.id, user3.id)
    end

    test "participant list persists across status changes", %{
      user1: user1,
      user2: user2
    } do
      raffle = insert(:raffle, creator: user1, status: "open")

      # Join while open
      {:ok, _} = Raffles.join_raffle(raffle.id, user2.id)
      assert Raffles.get_participant_count(raffle.id) == 1

      # Change status to closed
      {:ok, updated_raffle} = Raffles.update_raffle(raffle, %{status: "closed"})
      assert updated_raffle.status == "closed"

      # Participant still exists
      assert Raffles.get_participant_count(raffle.id) == 1
      assert Raffles.user_participating?(raffle.id, user2.id)

      # Can still list participants
      conn = make_request("/raffles/#{raffle.id}/participants", :get)
      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)
      assert body["count"] == 1
    end
  end
end
