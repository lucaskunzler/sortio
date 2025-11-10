defmodule Sortio.Raffles.Raffle do
  @moduledoc """
  Schema and changesets for raffle management.

  A raffle has a title, description, status, and optional draw date.
  Each raffle is created by a user and tracks its lifecycle through
  statuses: "open", "closed", "drawing", or "drawn".
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          title: String.t(),
          description: String.t() | nil,
          status: String.t(),
          draw_date: DateTime.t() | nil,
          winner_id: Ecto.UUID.t() | nil,
          drawn_at: DateTime.t() | nil,
          creator_id: Ecto.UUID.t(),
          creator: Sortio.Accounts.User.t() | Ecto.Association.NotLoaded.t(),
          winner: Sortio.Accounts.User.t() | Ecto.Association.NotLoaded.t() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, Uniq.UUID, autogenerate: true, version: 7}
  @foreign_key_type Uniq.UUID

  @valid_statuses ~w(open closed drawing drawn)
  @title_min_length 3
  @title_max_length 100
  @description_max_length 1000

  schema "raffles" do
    field(:title, :string)
    field(:description, :string)
    field(:status, :string)
    field(:draw_date, :utc_datetime_usec)
    field(:drawn_at, :utc_datetime_usec)

    belongs_to(:creator, Sortio.Accounts.User, foreign_key: :creator_id)
    belongs_to(:winner, Sortio.Accounts.User, foreign_key: :winner_id)

    has_many(:participants, Sortio.Raffles.Participant)

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Creates a changeset for creating new raffles.

  ## Parameters
    - raffle: The raffle struct
    - attrs: Map of attributes (title, description, draw_date)
    - creator_id: The UUID of the user creating the raffle

  ## Validations
    - title: required, min 3 chars, max 100 chars
    - description: optional, max 1000 chars
    - draw_date: required, must be in future
    - status: defaults to "open"
    - creator_id: set by system
  """
  def create_changeset(raffle, attrs, creator_id) do
    raffle
    |> cast(attrs, [:title, :description, :draw_date])
    |> validate_required([:title, :draw_date])
    |> apply_common_validations()
    |> put_change(:status, "open")
    |> put_change(:creator_id, creator_id)
    |> validate_required([:creator_id])
  end

  @doc """
  Creates a changeset for updating existing raffles.

  ## Parameters
    - raffle: The raffle struct
    - attrs: Map of attributes (title, description, draw_date, status)

  ## Validations
    - title: required, min 3 chars, max 100 chars
    - description: optional, max 1000 chars
    - status: must be in ["open", "closed", "drawing", "drawn"]
    - draw_date: optional, must be in future if provided
    - creator_id: cannot be changed
  """
  def update_changeset(raffle, attrs) do
    raffle
    |> cast(attrs, [:title, :description, :draw_date, :status])
    |> validate_required([:title])
    |> apply_common_validations()
    |> validate_inclusion(:status, @valid_statuses)
  end

  @doc """
  Creates a changeset for drawing a winner.

  ## Parameters
    - raffle: The raffle struct
    - winner_id: The UUID of the winner (or nil if no participants)

  ## Changes
    - Sets status to "drawn"
    - Sets winner_id
    - Sets drawn_at to current timestamp
  """
  def draw_changeset(raffle, winner_id) do
    raffle
    |> cast(%{}, [])
    |> put_change(:status, "drawn")
    |> put_change(:winner_id, winner_id)
    |> put_change(:drawn_at, DateTime.utc_now())
  end

  defp apply_common_validations(changeset) do
    changeset
    |> validate_length(:title, min: @title_min_length, max: @title_max_length)
    |> validate_length(:description, max: @description_max_length)
    |> validate_future_date(:draw_date)
  end

  defp validate_future_date(changeset, field) do
    validate_change(changeset, field, fn ^field, value ->
      if future_date?(value),
        do: [],
        else: [{field, "must be in the future"}]
    end)
  end

  defp future_date?(nil), do: false
  defp future_date?(date), do: DateTime.compare(date, DateTime.utc_now()) == :gt
end
