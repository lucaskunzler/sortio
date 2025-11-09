defmodule SortioApi.Controllers.ParticipantController do
  @moduledoc """
  Controller for participant operations.

  Handles raffle participation management:
  - POST /raffles/:id/join - Join a raffle (authenticated)
  - DELETE /raffles/:id/leave - Leave a raffle (authenticated)
  - GET /raffles/:id/participants - List participants (public)
  """

  alias Sortio.Raffles
  alias SortioApi.Helpers.ResponseHelpers
  alias SortioApi.Views.ParticipantView

  @spec join(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  @doc """
  POST /raffles/:id/join - User joins a raffle (authenticated).
  """
  def join(conn, raffle_id) do
    user = conn.assigns.current_user

    with :ok <- validate_uuid(raffle_id),
         {:ok, participant} <- Raffles.join_raffle(raffle_id, user.id) do
      ResponseHelpers.send_success(
        conn,
        %{participant: ParticipantView.render_participant(participant)},
        201
      )
    else
      {:error, :invalid_uuid} ->
        ResponseHelpers.send_error(conn, "Invalid raffle ID format", 400)

      {:error, :not_found} ->
        ResponseHelpers.send_error(conn, "Raffle not found", 404)

      {:error, :raffle_closed} ->
        ResponseHelpers.send_error(conn, "Cannot join a closed raffle", 422)

      {:error, %Ecto.Changeset{} = changeset} ->
        ResponseHelpers.send_error(conn, changeset, 422)
    end
  end

  @spec leave(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  @doc """
  DELETE /raffles/:id/leave - User leaves a raffle (authenticated).
  """
  def leave(conn, raffle_id) do
    user = conn.assigns.current_user

    with :ok <- validate_uuid(raffle_id),
         {:ok, _participant} <- Raffles.leave_raffle(raffle_id, user.id) do
      ResponseHelpers.send_json(conn, 204, nil)
    else
      {:error, :invalid_uuid} ->
        ResponseHelpers.send_error(conn, "Invalid raffle ID format", 400)

      {:error, :not_found} ->
        ResponseHelpers.send_error(conn, "You are not participating in this raffle", 404)
    end
  end

  @spec list(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  @doc """
  GET /raffles/:id/participants - List all participants for a raffle (public).
  """
  def list(conn, raffle_id) do
    case validate_uuid(raffle_id) do
      :ok ->
        participants = Raffles.list_participants(raffle_id)
        count = Raffles.get_participant_count(raffle_id)

        ResponseHelpers.send_success(
          conn,
          %{
            participants: ParticipantView.render_participants(participants),
            count: count
          },
          200
        )

      {:error, :invalid_uuid} ->
        ResponseHelpers.send_error(conn, "Invalid raffle ID format", 400)
    end
  end

  @spec validate_uuid(String.t()) :: :ok | {:error, :invalid_uuid}
  defp validate_uuid(id) do
    case Ecto.UUID.cast(id) do
      {:ok, _uuid} -> :ok
      :error -> {:error, :invalid_uuid}
    end
  end
end
