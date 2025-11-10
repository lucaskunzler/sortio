defmodule SortioApi.Controllers.ParticipantController do
  @moduledoc """
  Controller for participant operations.

  Handles raffle participation management:
  - POST /raffles/:raffle_id/participants - Create participation (authenticated)
  - DELETE /raffles/:raffle_id/participants/me - Remove participation (authenticated)
  - GET /raffles/:raffle_id/participants - List participants (public)
  """

  alias Sortio.Raffles
  alias SortioApi.Helpers.ResponseHelpers
  alias SortioApi.Views.ParticipantView

  @default_page 1
  @default_page_size 20

  @spec create(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  @doc """
  POST /raffles/:raffle_id/participants - User joins a raffle (authenticated).
  """
  def create(conn, raffle_id) do
    user = conn.assigns.current_user

    with :ok <- validate_uuid(raffle_id),
         {:ok, participant} <- Raffles.join_raffle(raffle_id, user.id) do
      ResponseHelpers.send_success(
        conn,
        %{participant: ParticipantView.render_participant(participant)},
        201
      )
    else
      {:error, error} ->
        handle_error(conn, error)
    end
  end

  @spec delete(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  @doc """
  DELETE /raffles/:raffle_id/participants/me - User leaves a raffle (authenticated).
  """
  def delete(conn, raffle_id) do
    user = conn.assigns.current_user

    with :ok <- validate_uuid(raffle_id),
         {:ok, _participant} <- Raffles.leave_raffle(raffle_id, user.id) do
      ResponseHelpers.send_json(conn, 204, nil)
    else
      {:error, error} ->
        handle_error(conn, error)
    end
  end

  @spec list(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  @doc """
  GET /raffles/:raffle_id/participants - List all participants for a raffle with pagination (public).
  """
  def list(conn, raffle_id) do
    with :ok <- validate_uuid(raffle_id),
         {:ok, _raffle} <- Raffles.get_raffle(raffle_id) do
      page = parse_positive_integer(conn.query_params["page"], @default_page)
      page_size = parse_positive_integer(conn.query_params["page_size"], @default_page_size)

      result = Raffles.list_participants(raffle_id, page: page, page_size: page_size)

      ResponseHelpers.send_success(
        conn,
        ParticipantView.render_paginated(result),
        200
      )
    else
      {:error, error} ->
        handle_error(conn, error)
    end
  end

  @spec validate_uuid(String.t()) :: :ok | {:error, :invalid_uuid}
  defp validate_uuid(id) do
    case Ecto.UUID.cast(id) do
      {:ok, _uuid} -> :ok
      :error -> {:error, :invalid_uuid}
    end
  end

  defp parse_positive_integer(nil, default), do: default

  defp parse_positive_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int > 0 -> int
      _ -> default
    end
  end

  defp parse_positive_integer(_, default), do: default

  defp handle_error(conn, error) do
    {message, status} = error_to_response(error)
    ResponseHelpers.send_error(conn, message, status)
  end

  defp error_to_response(error) do
    case error do
      :invalid_uuid ->
        {"Invalid raffle ID format", 400}

      :not_found ->
        {"Raffle not found", 404}

      :participant_not_found ->
        {"You are not participating in this raffle", 404}

      :raffle_closed ->
        {"Cannot join a closed raffle", 422}

      :draw_date_passed ->
        {"Cannot join raffle after draw date has passed", 422}

      :already_participating ->
        {"User already joined this raffle", 409}

      %Ecto.Changeset{} = changeset ->
        {changeset, 409}
    end
  end
end
