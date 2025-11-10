defmodule SortioApi.WinnerTest do
  use ExUnit.Case, async: true
  use SortioApi.ConnCase

  import Sortio.Factory

  alias Sortio.Raffles

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Sortio.Repo)
  end

  describe "GET /raffles/:id/winner" do
    test "returns 404 when raffle does not exist" do
      non_existent_id = Ecto.UUID.generate()

      conn = make_request("/raffles/#{non_existent_id}/winner", :get)

      assert conn.status == 404

      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Raffle not found"
    end

    test "returns 422 when raffle has not been drawn yet" do
      future_date = DateTime.add(DateTime.utc_now(), 3600, :second)
      raffle = insert(:raffle, status: "open", draw_date: future_date)

      conn = make_request("/raffles/#{raffle.id}/winner", :get)

      assert conn.status == 422

      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Raffle has not been drawn yet"
    end

    test "returns 404 when raffle is in drawing status" do
      raffle = insert(:raffle, status: "drawing")

      conn = make_request("/raffles/#{raffle.id}/winner", :get)

      assert conn.status == 422

      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Raffle has not been drawn yet"
    end

    test "returns winner info when raffle has been drawn with winner" do
      winner_user = insert(:user, name: "Lucky Winner", email: "winner@example.com")
      drawn_at = DateTime.utc_now()

      raffle =
        insert(:raffle,
          title: "Big Prize Raffle",
          status: "drawn",
          winner_id: winner_user.id,
          drawn_at: drawn_at
        )

      conn = make_request("/raffles/#{raffle.id}/winner", :get)

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)

      assert body["raffle_id"] == raffle.id
      assert body["raffle_title"] == "Big Prize Raffle"
      assert body["winner"]["id"] == winner_user.id
      assert body["winner"]["name"] == "Lucky Winner"
      assert body["winner"]["email"] == "winner@example.com"
      assert body["drawn_at"] != nil
    end

    test "returns null winner when raffle drawn with no participants" do
      drawn_at = DateTime.utc_now()

      raffle =
        insert(:raffle,
          status: "drawn",
          winner_id: nil,
          drawn_at: drawn_at
        )

      conn = make_request("/raffles/#{raffle.id}/winner", :get)

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)
      assert body["raffle_id"] == raffle.id
      assert body["winner"] == nil
      assert body["drawn_at"] != nil
    end

    test "winner endpoint is public (no authentication required)" do
      winner = insert(:user)

      raffle =
        insert(:raffle, status: "drawn", winner_id: winner.id, drawn_at: DateTime.utc_now())

      # No auth token
      conn = make_request("/raffles/#{raffle.id}/winner", :get)

      assert conn.status == 200
    end

    test "returns 400 for invalid UUID format" do
      conn = make_request("/raffles/invalid-uuid/winner", :get)

      assert conn.status == 400

      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Invalid raffle ID format"
    end
  end

  describe "GET /raffles/:id/winner - integration with draw process" do
    test "winner is accessible after automatic draw" do
      raffle = insert(:raffle, status: "open")
      participant1 = insert(:participant, raffle: raffle)
      participant2 = insert(:participant, raffle: raffle)

      # Perform draw
      {:ok, _drawn_raffle} = Raffles.draw_winner(raffle.id)

      # Verify winner endpoint returns the winner
      conn = make_request("/raffles/#{raffle.id}/winner", :get)

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)
      assert body["winner"]["id"] in [participant1.user_id, participant2.user_id]
      assert body["drawn_at"] != nil
    end
  end
end
