defmodule SortioApi.Views.WinnerView do
  @moduledoc """
  View functions for rendering raffle winner data in API responses.
  """

  alias Sortio.Raffles.Raffle
  alias SortioApi.Views.UserView

  @type winner_json :: %{
          raffle_id: Ecto.UUID.t(),
          raffle_title: String.t(),
          winner: map() | nil,
          drawn_at: DateTime.t()
        }

  @spec render_winner(Raffle.t()) :: winner_json()
  @doc """
  Renders winner information for a drawn raffle.

  Returns the raffle ID, title, winner details, and draw timestamp.
  Winner can be nil if raffle had no participants.
  """
  def render_winner(%Raffle{} = raffle) do
    %{
      raffle_id: raffle.id,
      raffle_title: raffle.title,
      winner: raffle.winner && UserView.render_user(raffle.winner),
      drawn_at: raffle.drawn_at
    }
  end
end
