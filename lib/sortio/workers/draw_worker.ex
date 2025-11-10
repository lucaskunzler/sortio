defmodule Sortio.Workers.DrawWorker do
  @moduledoc """
  Oban worker for drawing raffle winners.

  This worker is scheduled when a raffle is created and executes at the
  raffle's draw_date. It handles the automatic winner selection process.

  The worker is idempotent - it safely handles cases where the raffle
  has already been drawn by another worker or manual process.
  """
  use Oban.Worker, queue: :draws, max_attempts: 3

  alias Sortio.Raffles

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"raffle_id" => raffle_id}}) do
    Logger.info("Drawing winner for raffle #{raffle_id}")

    case Raffles.draw_winner(raffle_id) do
      {:ok, %Sortio.Raffles.Raffle{} = raffle} ->
        Logger.info(
          "Successfully drew winner for raffle #{raffle_id}, winner: #{raffle.winner_id}"
        )

        :ok

      {:ok, :already_claimed} ->
        Logger.info("Raffle #{raffle_id} already claimed/drawn")
        :ok

      {:error, reason} ->
        Logger.error("Failed to draw winner for raffle #{raffle_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
