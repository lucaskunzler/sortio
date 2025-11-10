defmodule SortioApi.ParticipantsTest do
  @moduledoc """
  Integration tests for participant API endpoints.

  Tests cover joining, leaving, and listing participants,
  including authentication, authorization, and business rules.
  """
  use ExUnit.Case, async: true
  use SortioApi.ConnCase

  alias Sortio.Raffles

  @fake_uuid "018e1234-5678-7abc-def0-123456789012"
  @missing_auth_error "Missing or invalid authorization header"
  @invalid_uuid_error "Invalid raffle ID format"
  @raffle_not_found_error "Raffle not found"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Sortio.Repo)

    # Create test users
    user1 = insert(:user, name: "Test User 1", email: "user1@example.com")
    user2 = insert(:user, name: "Test User 2", email: "user2@example.com")
    user3 = insert(:user, name: "Test User 3", email: "user3@example.com")

    # Get tokens
    token1 = get_user_token("user1@example.com")
    token2 = get_user_token("user2@example.com")
    token3 = get_user_token("user3@example.com")

    %{
      user1: user1,
      user2: user2,
      user3: user3,
      token1: token1,
      token2: token2,
      token3: token3
    }
  end

  # Helper functions
  defp get_user_token(email) do
    login_params = %{"email" => email, "password" => "password123"}
    login_conn = make_request("/login", :post, Jason.encode!(login_params))
    Jason.decode!(login_conn.resp_body)["token"]
  end

  defp assert_error_response(conn, status, message) do
    assert conn.status == status
    body = Jason.decode!(conn.resp_body)
    assert body["error"] == message
  end

  defp assert_error_contains(conn, status, text) do
    assert conn.status == status
    body = Jason.decode!(conn.resp_body)
    assert String.contains?(body["error"], text)
  end

  describe "POST /raffles/:raffle_id/participants" do
    test "returns 401 without authentication token", %{user1: user1} do
      raffle = insert(:raffle, creator: user1)
      conn = make_request("/raffles/#{raffle.id}/participants", :post)
      assert_error_response(conn, 401, @missing_auth_error)
    end

    test "returns 201 and creates participation with valid token", %{user1: user1, token2: token2} do
      raffle = insert(:raffle, creator: user1)
      conn = make_authenticated_request("/raffles/#{raffle.id}/participants", :post, token2)

      assert conn.status == 201
      body = Jason.decode!(conn.resp_body)
      assert body["participant"]["raffle_id"] == raffle.id
      assert body["participant"]["id"]
      assert body["participant"]["inserted_at"]
      assert Raffles.get_participant_count(raffle.id) == 1
    end

    test "returns 409 if user already joined the raffle", %{user1: user1, token2: token2} do
      raffle = insert(:raffle, creator: user1)

      conn1 = make_authenticated_request("/raffles/#{raffle.id}/participants", :post, token2)
      assert conn1.status == 201

      conn2 = make_authenticated_request("/raffles/#{raffle.id}/participants", :post, token2)
      assert_error_contains(conn2, 409, "already joined")
    end

    test "creator can join their own raffle", %{user1: user1, token1: token1} do
      raffle = insert(:raffle, creator: user1)
      conn = make_authenticated_request("/raffles/#{raffle.id}/participants", :post, token1)

      assert conn.status == 201
      body = Jason.decode!(conn.resp_body)
      assert body["participant"]["raffle_id"] == raffle.id
    end

    test "returns 404 if raffle doesn't exist", %{token1: token1} do
      conn = make_authenticated_request("/raffles/#{@fake_uuid}/participants", :post, token1)
      assert_error_response(conn, 404, @raffle_not_found_error)
    end

    test "returns 400 with invalid UUID format", %{token1: token1} do
      conn = make_authenticated_request("/raffles/invalid-uuid/participants", :post, token1)
      assert_error_response(conn, 400, @invalid_uuid_error)
    end

    test "returns 422 when trying to join closed raffle", %{user1: user1, token2: token2} do
      raffle = insert(:raffle, creator: user1, status: "closed")
      conn = make_authenticated_request("/raffles/#{raffle.id}/participants", :post, token2)
      assert_error_response(conn, 422, "Cannot join a closed raffle")
    end
  end

  describe "DELETE /raffles/:raffle_id/participants/me" do
    test "returns 401 without authentication token", %{user1: user1} do
      raffle = insert(:raffle, creator: user1)
      conn = make_request("/raffles/#{raffle.id}/participants/me", :delete)
      assert_error_response(conn, 401, @missing_auth_error)
    end

    test "returns 204 when successfully leaving raffle", %{
      user1: user1,
      user2: user2,
      token2: token2
    } do
      raffle = insert(:raffle, creator: user1)
      {:ok, _participant} = Raffles.join_raffle(raffle.id, user2.id)
      assert Raffles.get_participant_count(raffle.id) == 1

      conn = make_authenticated_request("/raffles/#{raffle.id}/participants/me", :delete, token2)

      assert conn.status == 204
      assert conn.resp_body == "null"
      assert Raffles.get_participant_count(raffle.id) == 0
      refute Raffles.user_participating?(raffle.id, user2.id)
    end

    test "returns 404 if user is not participating", %{user1: user1, token2: token2} do
      raffle = insert(:raffle, creator: user1)
      conn = make_authenticated_request("/raffles/#{raffle.id}/participants/me", :delete, token2)
      assert_error_response(conn, 404, "You are not participating in this raffle")
    end

    test "returns 400 with invalid UUID format", %{token1: token1} do
      conn = make_authenticated_request("/raffles/invalid-uuid/participants/me", :delete, token1)
      assert_error_response(conn, 400, @invalid_uuid_error)
    end

    test "returns 404 if raffle doesn't exist", %{token1: token1} do
      conn = make_authenticated_request("/raffles/#{@fake_uuid}/participants/me", :delete, token1)
      assert_error_response(conn, 404, "You are not participating in this raffle")
    end
  end

  describe "GET /raffles/:raffle_id/participants" do
    test "works without authentication and returns empty list", %{user1: user1} do
      raffle = insert(:raffle, creator: user1)
      conn = make_request("/raffles/#{raffle.id}/participants", :get)

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["participants"] == []
      assert body["pagination"]["total_count"] == 0
      assert body["pagination"]["page"] == 1
    end

    test "returns all participants with user info", %{user1: user1, user2: user2, user3: user3} do
      raffle = insert(:raffle, creator: user1)
      {:ok, _} = Raffles.join_raffle(raffle.id, user2.id)
      {:ok, _} = Raffles.join_raffle(raffle.id, user3.id)

      conn = make_request("/raffles/#{raffle.id}/participants", :get)
      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)
      assert length(body["participants"]) == 2
      assert body["pagination"]["total_count"] == 2

      participants = body["participants"]
      user_ids = Enum.map(participants, & &1["user"]["id"])
      assert user2.id in user_ids
      assert user3.id in user_ids

      # Verify structure
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
      {:ok, _} = Raffles.join_raffle(raffle.id, user2.id)
      {:ok, _} = Raffles.join_raffle(raffle.id, user3.id)

      conn = make_request("/raffles/#{raffle.id}/participants", :get)
      body = Jason.decode!(conn.resp_body)
      participants = body["participants"]

      assert length(participants) == 2

      timestamps =
        participants
        |> Enum.map(& &1["inserted_at"])
        |> Enum.map(fn ts ->
          {:ok, naive_datetime} = NaiveDateTime.from_iso8601(ts)
          naive_datetime
        end)

      sorted_desc = Enum.sort(timestamps, {:desc, NaiveDateTime})
      assert timestamps == sorted_desc
    end

    test "returns 400 with invalid UUID format" do
      conn = make_request("/raffles/invalid-uuid/participants", :get)
      assert_error_response(conn, 400, @invalid_uuid_error)
    end

    test "returns 404 if raffle doesn't exist" do
      conn = make_request("/raffles/#{@fake_uuid}/participants", :get)
      assert_error_response(conn, 404, @raffle_not_found_error)
    end
  end

  describe "Edge cases" do
    test "user can join after leaving", %{user1: user1, token2: token2} do
      raffle = insert(:raffle, creator: user1)

      conn1 = make_authenticated_request("/raffles/#{raffle.id}/participants", :post, token2)
      assert conn1.status == 201
      assert Raffles.get_participant_count(raffle.id) == 1

      conn2 = make_authenticated_request("/raffles/#{raffle.id}/participants/me", :delete, token2)
      assert conn2.status == 204
      assert Raffles.get_participant_count(raffle.id) == 0

      conn3 = make_authenticated_request("/raffles/#{raffle.id}/participants", :post, token2)
      assert conn3.status == 201
      assert Raffles.get_participant_count(raffle.id) == 1
    end

    test "participant count is accurate with multiple joins and leaves", %{
      user1: user1,
      user2: user2,
      user3: user3
    } do
      raffle = insert(:raffle, creator: user1)
      assert Raffles.get_participant_count(raffle.id) == 0

      {:ok, _} = Raffles.join_raffle(raffle.id, user2.id)
      assert Raffles.get_participant_count(raffle.id) == 1

      {:ok, _} = Raffles.join_raffle(raffle.id, user3.id)
      assert Raffles.get_participant_count(raffle.id) == 2

      {:ok, _} = Raffles.leave_raffle(raffle.id, user2.id)
      assert Raffles.get_participant_count(raffle.id) == 1
      assert Raffles.user_participating?(raffle.id, user3.id)
      refute Raffles.user_participating?(raffle.id, user2.id)
    end

    test "user_participating? returns correct status", %{user1: user1, user2: user2} do
      raffle = insert(:raffle, creator: user1)

      refute Raffles.user_participating?(raffle.id, user2.id)

      {:ok, _} = Raffles.join_raffle(raffle.id, user2.id)
      assert Raffles.user_participating?(raffle.id, user2.id)

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

      conn1 = make_authenticated_request("/raffles/#{raffle.id}/participants", :post, token2)
      assert conn1.status == 201

      conn2 = make_authenticated_request("/raffles/#{raffle.id}/participants", :post, token3)
      assert conn2.status == 201

      assert Raffles.get_participant_count(raffle.id) == 2
      assert Raffles.user_participating?(raffle.id, user2.id)
      assert Raffles.user_participating?(raffle.id, user3.id)
    end

    test "participant list persists across status changes", %{user1: user1, user2: user2} do
      raffle = insert(:raffle, creator: user1, status: "open")

      {:ok, _} = Raffles.join_raffle(raffle.id, user2.id)
      assert Raffles.get_participant_count(raffle.id) == 1

      {:ok, updated_raffle} = Raffles.update_raffle(raffle, %{status: "closed"})
      assert updated_raffle.status == "closed"

      assert Raffles.get_participant_count(raffle.id) == 1
      assert Raffles.user_participating?(raffle.id, user2.id)

      conn = make_request("/raffles/#{raffle.id}/participants", :get)
      body = Jason.decode!(conn.resp_body)
      assert body["pagination"]["total_count"] == 1
    end
  end

  describe "POST /raffles/:raffle_id/participants - draw_date validation" do
    test "cannot join raffle after draw_date has passed", %{user1: user1, token2: token2} do
      past_date = DateTime.add(DateTime.utc_now(), -60, :second)
      raffle = insert(:raffle, creator: user1, status: "open", draw_date: past_date)

      conn = make_authenticated_request("/raffles/#{raffle.id}/participants", :post, token2)

      assert conn.status == 422

      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Cannot join raffle after draw date has passed"
    end

    test "can join raffle before draw_date", %{user1: user1, token2: token2} do
      future_date = DateTime.add(DateTime.utc_now(), 3600, :second)
      raffle = insert(:raffle, creator: user1, status: "open", draw_date: future_date)

      conn = make_authenticated_request("/raffles/#{raffle.id}/participants", :post, token2)

      assert conn.status == 201

      body = Jason.decode!(conn.resp_body)
      assert body["participant"]["raffle_id"] == raffle.id
    end
  end
end
