defmodule SortioApi.Views.RaffleView do
  @moduledoc """
  View functions for rendering raffle data in API responses.
  """

  alias Sortio.Raffles.Raffle
  alias SortioApi.Views.UserView

  @type raffle_json :: %{
          id: Ecto.UUID.t(),
          title: String.t(),
          description: String.t() | nil,
          status: String.t(),
          draw_date: DateTime.t() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t(),
          creator: UserView.user_minimal_json() | nil
        }

  @spec render_raffle(Raffle.t()) :: raffle_json()
  @doc """
  Renders a raffle with optional creator information.
  """
  def render_raffle(%Raffle{} = raffle) do
    base = %{
      id: raffle.id,
      title: raffle.title,
      description: raffle.description,
      status: raffle.status,
      draw_date: raffle.draw_date,
      inserted_at: raffle.inserted_at,
      updated_at: raffle.updated_at
    }

    case raffle.creator do
      %Ecto.Association.NotLoaded{} ->
        base

      creator ->
        Map.put(base, :creator, UserView.render_user_minimal(creator))
    end
  end

  @spec render_raffles([Raffle.t()]) :: [raffle_json()]
  @doc """
  Renders a list of raffles.
  """
  def render_raffles(raffles) when is_list(raffles) do
    Enum.map(raffles, &render_raffle/1)
  end

  @spec render_paginated(Sortio.Raffles.pagination_result()) :: map()
  @doc """
  Renders paginated raffle response.
  """
  def render_paginated(result) do
    %{
      raffles: render_raffles(result.entries),
      pagination: %{
        page: result.page,
        page_size: result.page_size,
        total_count: result.total_count,
        total_pages: result.total_pages
      }
    }
  end
end
