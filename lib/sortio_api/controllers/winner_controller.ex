defmodule SortioApi.Controllers.WinnerController do
  @moduledoc """
  Controller for raffle winner endpoint.

  Provides public access to view raffle winners after a draw has occurred.
  """

  alias Sortio.Raffles
  alias Sortio.Repo
  alias SortioApi.Helpers.ResponseHelpers
  alias SortioApi.Views.WinnerView

  @spec show(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  @doc """
  GET /raffles/:id/winner - Get the winner of a raffle (public endpoint).

  Returns winner information if the raffle has been drawn.
  Returns 404 if raffle doesn't exist or hasn't been drawn yet.
  """
  def show(conn, raffle_id) do
    with :ok <- validate_uuid(raffle_id),
         {:ok, raffle} <- Raffles.get_raffle(raffle_id),
         :ok <- validate_drawn(raffle) do
      # Preload winner if exists
      raffle = Repo.preload(raffle, :winner)

      ResponseHelpers.send_success(
        conn,
        WinnerView.render_winner(raffle),
        200
      )
    else
      {:error, :invalid_uuid} ->
        ResponseHelpers.send_error(conn, "Invalid raffle ID format", 400)

      {:error, :not_found} ->
        ResponseHelpers.send_error(conn, "Raffle not found", 404)

      {:error, :not_drawn} ->
        ResponseHelpers.send_error(conn, "Draw has not occurred yet", 404)
    end
  end

  defp validate_uuid(id) do
    case Ecto.UUID.cast(id) do
      {:ok, _uuid} -> :ok
      :error -> {:error, :invalid_uuid}
    end
  end

  defp validate_drawn(raffle) do
    if raffle.status == "drawn" do
      :ok
    else
      {:error, :not_drawn}
    end
  end
end
