defmodule Sortio.Workers.DrawWorkerTest do
  use ExUnit.Case, async: true
  use Sortio.DataCase
  use Oban.Testing, repo: Sortio.Repo

  alias Sortio.Workers.DrawWorker
  alias Sortio.Repo

  describe "perform/1" do
    test "successfully draws winner when raffle has participants" do
      raffle = insert(:raffle, status: "open")
      participant1 = insert(:participant, raffle: raffle)
      participant2 = insert(:participant, raffle: raffle)
      participant3 = insert(:participant, raffle: raffle)

      assert :ok = perform_job(DrawWorker, %{raffle_id: raffle.id})

      raffle = Repo.reload!(raffle) |> Repo.preload(:winner)
      assert raffle.status == "drawn"

      assert raffle.winner_id in [
               participant1.user_id,
               participant2.user_id,
               participant3.user_id
             ]

      assert raffle.drawn_at != nil
    end

    test "marks raffle as drawn even when no participants" do
      raffle = insert(:raffle, status: "open")

      assert :ok = perform_job(DrawWorker, %{raffle_id: raffle.id})

      raffle = Repo.reload!(raffle)
      assert raffle.status == "drawn"
      assert raffle.winner_id == nil
      assert raffle.drawn_at != nil
    end

    test "returns ok when raffle already claimed by another worker" do
      raffle = insert(:raffle, status: "drawing")

      assert :ok = perform_job(DrawWorker, %{raffle_id: raffle.id})
    end

    test "returns ok when raffle already drawn" do
      winner = insert(:user)
      raffle = insert(:raffle, status: "drawn", winner_id: winner.id)

      assert :ok = perform_job(DrawWorker, %{raffle_id: raffle.id})
    end

    test "retries on failure" do
      assert {:error, _} = perform_job(DrawWorker, %{raffle_id: Ecto.UUID.generate()})
    end
  end
end
