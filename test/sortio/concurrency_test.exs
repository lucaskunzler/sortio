defmodule Sortio.Raffles.ConcurrencyTest do
  # Must be serial for concurrency test
  use ExUnit.Case, async: false
  use Sortio.DataCase

  import Sortio.Factory

  alias Sortio.Raffles
  alias Sortio.Repo

  @moduletag :concurrency
  describe "concurrent draw attempts" do
    test "10 concurrent workers can only draw once" do
      raffle = insert(:raffle, status: "open")

      # Create 5 participants
      participants = for _ <- 1..5, do: insert(:participant, raffle: raffle)

      # Allow spawned tasks to use the test's database connection
      parent = self()
      allow_fn = fn -> Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self()) end

      # Spawn 10 concurrent tasks trying to draw
      tasks =
        for _ <- 1..10 do
          Task.async(fn ->
            allow_fn.()
            Raffles.draw_winner(raffle.id)
          end)
        end

      # Collect results
      results = Enum.map(tasks, &Task.await/1)

      # Exactly one should succeed with raffle
      successful_draws = Enum.filter(results, &match?({:ok, %Sortio.Raffles.Raffle{}}, &1))
      claimed_responses = Enum.filter(results, &match?({:ok, :already_claimed}, &1))

      assert length(successful_draws) == 1
      assert length(claimed_responses) == 9

      # Verify database state
      raffle = Repo.reload!(raffle)
      assert raffle.status == "drawn"
      assert raffle.winner_id in Enum.map(participants, & &1.user_id)

      # Verify winner was only set once (no overwrites)
      [{:ok, drawn_raffle}] = successful_draws
      assert drawn_raffle.winner_id == raffle.winner_id
    end

    test "concurrent participants joining and draw attempt" do
      future_date = DateTime.add(DateTime.utc_now(), 60, :second)
      raffle = insert(:raffle, status: "open", draw_date: future_date)

      users = for _ <- 1..10, do: insert(:user)

      # Allow spawned tasks to use the test's database connection
      parent = self()
      allow_fn = fn -> Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self()) end

      # Spawn tasks: 10 joining + 1 trying to draw
      join_tasks =
        for user <- users do
          Task.async(fn ->
            allow_fn.()
            Raffles.join_raffle(raffle.id, user.id)
          end)
        end

      draw_task =
        Task.async(fn ->
          allow_fn.()
          Raffles.draw_winner(raffle.id)
        end)

      # Wait for all
      join_results = Enum.map(join_tasks, &Task.await/1)
      draw_result = Task.await(draw_task)

      # With atomic status updates, joins may succeed or fail depending on timing
      # The important thing is that the draw succeeds and finalizes correctly
      successful_joins = Enum.count(join_results, &match?({:ok, _}, &1))
      failed_joins = Enum.count(join_results, &match?({:error, :raffle_closed}, &1))

      # All operations should complete (either success or raffle_closed)
      assert successful_joins + failed_joins == 10

      # Draw should succeed
      assert {:ok, _} = draw_result

      # Verify final state is drawn
      raffle = Repo.reload!(raffle)
      assert raffle.status == "drawn"
    end
  end
end
