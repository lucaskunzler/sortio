defmodule Sortio.Raffles.Participant do
  @moduledoc """
  Schema and changesets for raffle participation.

  A participant represents a user joining a raffle. Each participant
  is uniquely identified by the combination of user_id and raffle_id,
  ensuring a user can only join a raffle once.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "participants" do
    belongs_to(:user, Sortio.Accounts.User, foreign_key: :user_id)
    belongs_to(:raffle, Sortio.Raffles.Raffle, foreign_key: :raffle_id)

    timestamps()
  end

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          user_id: Ecto.UUID.t() | nil,
          raffle_id: Ecto.UUID.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @type changeset :: Ecto.Changeset.t(t())

  @doc """
  Creates a changeset for creating a new participant.

  ## Parameters
  - `participant`: The participant struct.
  - `attrs`: Map containing raffle_id and user_id

  ## Validations
  - `raffle_id` and `user_id` are required
  - Uniqueness of `raffle_id` and `user_id` combination

  ## Examples

      iex> attrs = %{raffle_id: "...", user_id: "..."}
      iex> Sortio.Raffles.Participant.create_changeset(%Sortio.Raffles.Participant{}, attrs)
      %Ecto.Changeset{...}

  """
  @spec create_changeset(t(), map()) :: changeset()
  def create_changeset(participant, attrs) do
    participant
    |> cast(attrs, [:raffle_id, :user_id])
    |> validate_required([:raffle_id, :user_id])
    |> unique_constraint([:user_id, :raffle_id],
      name: :participants_user_id_raffle_id_index,
      message: "User already joined this raffle"
    )
  end
end
