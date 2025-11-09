defmodule SortioApi.Controllers.RaffleController do
  @moduledoc """
  Controller for raffle CRUD operations.

  Handles raffle resource management following REST conventions:
  - GET /raffles - List raffles (public)
  - GET /raffles/:id - Show raffle (public)
  - POST /raffles - Create raffle (authenticated)
  - PUT /raffles/:id - Update raffle (authenticated, owner only)
  - DELETE /raffles/:id - Delete raffle (authenticated, owner only)
  """

  alias Sortio.Raffles
  alias SortioApi.Helpers.ResponseHelpers
  alias SortioApi.Views.RaffleView

  @default_page 1
  @default_page_size 20

  @spec index(Plug.Conn.t()) :: Plug.Conn.t()
  @doc """
  GET /raffles - List raffles with optional filtering and pagination.
  """
  def index(conn) do
    status = conn.query_params["status"]
    page = parse_positive_integer(conn.query_params["page"], @default_page)
    page_size = parse_positive_integer(conn.query_params["page_size"], @default_page_size)

    query_opts =
      []
      |> Keyword.put(:page, page)
      |> Keyword.put(:page_size, page_size)
      |> maybe_put(:status, status)

    result = Raffles.list_raffles(query_opts)

    ResponseHelpers.send_success(
      conn,
      RaffleView.render_paginated(result),
      200
    )
  end

  @spec show(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  @doc """
  GET /raffles/:id - Get a single raffle by ID.
  """
  def show(conn, id) do
    with :ok <- validate_uuid(id),
         {:ok, raffle} <- Raffles.get_raffle(id) do
      ResponseHelpers.send_success(
        conn,
        %{raffle: RaffleView.render_raffle(raffle)},
        200
      )
    else
      {:error, :invalid_uuid} ->
        ResponseHelpers.send_error(conn, "Invalid raffle ID format", 400)

      {:error, :not_found} ->
        ResponseHelpers.send_error(conn, "Raffle not found", 404)
    end
  end

  @spec create(Plug.Conn.t()) :: Plug.Conn.t()
  @doc """
  POST /raffles - Create a new raffle (authenticated).
  """
  def create(conn) do
    user = conn.assigns.current_user

    with {:ok, params} <- parse_raffle_params(conn.body_params),
         {:ok, raffle} <- Raffles.create_raffle(params, user.id) do
      ResponseHelpers.send_success(
        conn,
        %{raffle: RaffleView.render_raffle(raffle)},
        201
      )
    else
      {:error, error} ->
        ResponseHelpers.send_error(conn, error, 422)
    end
  end

  @spec update(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  @doc """
  PUT /raffles/:id - Update a raffle (authenticated, owner only).
  """
  def update(conn, id) do
    user = conn.assigns.current_user

    with :ok <- validate_uuid(id),
         {:ok, raffle} <- Raffles.get_raffle(id),
         :ok <- authorize_owner(raffle, user),
         {:ok, updated_raffle} <- Raffles.update_raffle(raffle, conn.body_params) do
      ResponseHelpers.send_success(
        conn,
        %{raffle: RaffleView.render_raffle(updated_raffle)},
        200
      )
    else
      {:error, error} ->
        handle_error(conn, error)
    end
  end

  @spec delete(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  @doc """
  DELETE /raffles/:id - Delete a raffle (authenticated, owner only).
  """
  def delete(conn, id) do
    user = conn.assigns.current_user

    with :ok <- validate_uuid(id),
         {:ok, raffle} <- Raffles.get_raffle(id),
         :ok <- authorize_owner(raffle, user),
         {:ok, _raffle} <- Raffles.delete_raffle(raffle) do
      ResponseHelpers.send_json(conn, 204, nil)
    else
      {:error, error} ->
        handle_error(conn, error)
    end
  end

  defp parse_raffle_params(params) do
    case parse_draw_date(Map.get(params, "draw_date")) do
      {:ok, draw_date} ->
        {:ok,
         %{
           title: Map.get(params, "title"),
           description: Map.get(params, "description"),
           draw_date: draw_date
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_draw_date(nil), do: {:ok, nil}

  defp parse_draw_date(draw_date) when is_binary(draw_date) do
    case DateTime.from_iso8601(draw_date) do
      {:ok, datetime, _offset} ->
        {:ok, datetime}

      {:error, _} ->
        {:error, "Invalid date format. Expected ISO8601 format (e.g., 2024-01-01T12:00:00Z)"}
    end
  end

  defp parse_draw_date(_),
    do: {:error, "Invalid date format. Expected ISO8601 format (e.g., 2024-01-01T12:00:00Z)"}

  defp parse_positive_integer(nil, default), do: default

  defp parse_positive_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int > 0 -> int
      _ -> default
    end
  end

  defp parse_positive_integer(_, default), do: default

  defp validate_uuid(id) do
    case Ecto.UUID.cast(id) do
      {:ok, _uuid} -> :ok
      :error -> {:error, :invalid_uuid}
    end
  end

  defp authorize_owner(raffle, user) do
    if Raffles.user_owns_raffle?(raffle, user) do
      :ok
    else
      {:error, :forbidden}
    end
  end

  defp maybe_put(keyword, _key, nil), do: keyword
  defp maybe_put(keyword, key, value), do: Keyword.put(keyword, key, value)

  defp handle_error(conn, error) do
    case error do
      :invalid_uuid ->
        ResponseHelpers.send_error(conn, "Invalid raffle ID", 400)

      :not_found ->
        ResponseHelpers.send_error(conn, "Raffle not found", 404)

      :forbidden ->
        ResponseHelpers.send_error(conn, "You don't have permission to modify this raffle", 403)

      error ->
        ResponseHelpers.send_error(conn, error, 422)
    end
  end
end
