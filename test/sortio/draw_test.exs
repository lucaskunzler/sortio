defmodule Sortio.Raffles.DrawTest do
  use ExUnit.Case, async: true
  use Sortio.DataCase
  use Oban.Testing, repo: Sortio.Repo

  alias Sortio.Raffles
  alias Sortio.Raffles.Raffle
  alias Sortio.Repo

  describe "draw_winner/1" do
    test "successfully draws a random winner from participants" do
      raffle = insert(:raffle, status: "open")
      participant1 = insert(:participant, raffle: raffle)
      participant2 = insert(:participant, raffle: raffle)
      participant3 = insert(:participant, raffle: raffle)

      assert {:ok, drawn_raffle} = Raffles.draw_winner(raffle.id)

      assert drawn_raffle.status == "drawn"

      assert drawn_raffle.winner_id in [
               participant1.user_id,
               participant2.user_id,
               participant3.user_id
             ]

      assert drawn_raffle.drawn_at != nil
      assert DateTime.before?(drawn_raffle.drawn_at, DateTime.utc_now())
    end

    test "marks raffle as drawn with no winner when no participants" do
      raffle = insert(:raffle, status: "open")

      assert {:ok, drawn_raffle} = Raffles.draw_winner(raffle.id)

      assert drawn_raffle.status == "drawn"
      assert drawn_raffle.winner_id == nil
      assert drawn_raffle.drawn_at != nil
    end

    test "prevents concurrent draws using optimistic locking" do
      raffle = insert(:raffle, status: "open")
      insert(:participant, raffle: raffle)
      insert(:participant, raffle: raffle)

      # Simulate two concurrent draw attempts
      task1 = Task.async(fn -> Raffles.draw_winner(raffle.id) end)
      task2 = Task.async(fn -> Raffles.draw_winner(raffle.id) end)

      results = [Task.await(task1), Task.await(task2)]

      # One should succeed with raffle, one should return already_claimed
      assert Enum.count(results, &match?({:ok, %Raffle{}}, &1)) == 1
      assert Enum.count(results, &match?({:ok, :already_claimed}, &1)) == 1

      # Verify final state
      raffle = Repo.reload!(raffle)
      assert raffle.status == "drawn"
      assert raffle.winner_id != nil
    end

    test "returns already_claimed when raffle status is not open" do
      raffle = insert(:raffle, status: "closed")

      assert {:ok, :already_claimed} = Raffles.draw_winner(raffle.id)
    end

    test "returns already_claimed when raffle is already drawing" do
      raffle = insert(:raffle, status: "drawing")

      assert {:ok, :already_claimed} = Raffles.draw_winner(raffle.id)
    end

    test "returns already_claimed when raffle already drawn" do
      winner = insert(:user)
      raffle = insert(:raffle, status: "drawn", winner_id: winner.id)

      assert {:ok, :already_claimed} = Raffles.draw_winner(raffle.id)
    end
  end

  describe "create_raffle/2 with Oban scheduling" do
    test "schedules draw job when raffle is created" do
      user = insert(:user)
      draw_date = DateTime.add(DateTime.utc_now(), 3600, :second)

      {:ok, raffle} =
        Raffles.create_raffle(
          %{
            title: "Test Raffle",
            description: "Test",
            draw_date: draw_date
          },
          user.id
        )

      assert_enqueued(
        worker: Sortio.Workers.DrawWorker,
        args: %{raffle_id: raffle.id}
      )

      assert_enqueued(
        worker: Sortio.Workers.DrawWorker,
        args: %{raffle_id: raffle.id},
        scheduled_at: draw_date
      )
    end

    test "requires draw_date to create raffle" do
      user = insert(:user)

      assert {:error, changeset} =
               Raffles.create_raffle(
                 %{
                   title: "Test Raffle",
                   description: "Test"
                   # Missing draw_date
                 },
                 user.id
               )

      assert %{draw_date: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates draw_date is in the future" do
      user = insert(:user)
      past_date = DateTime.add(DateTime.utc_now(), -3600, :second)

      assert {:error, changeset} =
               Raffles.create_raffle(
                 %{
                   title: "Test Raffle",
                   draw_date: past_date
                 },
                 user.id
               )

      assert %{draw_date: [_message]} = errors_on(changeset)
    end
  end
end
