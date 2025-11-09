defmodule SortioApi.Views.ParticipantView do
  @moduledoc """
  View functions for rendering participant data in API responses.
  """

  alias Sortio.Raffles.Participant
  alias SortioApi.Views.UserView

  @type participant_json :: %{
          id: Ecto.UUID.t(),
          raffle_id: Ecto.UUID.t(),
          user_id: Ecto.UUID.t(),
          inserted_at: DateTime.t(),
          user: UserView.user_minimal_json() | nil
        }

  @spec render_participant(Participant.t()) :: participant_json()
  @doc """
  Renders a participant with optional user information.
  """
  def render_participant(%Participant{} = participant) do
    base = %{
      id: participant.id,
      raffle_id: participant.raffle_id,
      user_id: participant.user_id,
      inserted_at: participant.inserted_at
    }

    case participant.user do
      %Ecto.Association.NotLoaded{} ->
        base

      user ->
        Map.put(base, :user, UserView.render_user_minimal(user))
    end
  end

  @spec render_participants([Participant.t()]) :: [participant_json()]
  @doc """
  Renders a list of participants.
  """
  def render_participants(participants) when is_list(participants) do
    Enum.map(participants, &render_participant/1)
  end
end
