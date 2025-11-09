defmodule Sortio.Accounts.User do
  @moduledoc """
  User schema
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          name: String.t(),
          email: String.t(),
          password_hash: String.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t(),
          raffles: [Sortio.Raffles.Raffle.t()] | Ecto.Association.NotLoaded.t()
        }

  @primary_key {:id, Uniq.UUID, autogenerate: true, version: 7}
  @foreign_key_type Uniq.UUID

  schema "users" do
    field(:name, :string)
    field(:email, :string)
    field(:password_hash, :string)
    field(:password, :string, virtual: true, redact: true)

    timestamps(type: :utc_datetime_usec)

    has_many(:raffles, Sortio.Raffles.Raffle, foreign_key: :creator_id)
  end

  @doc """
    Changeset for creating a new user.
  """
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :password])
    |> validate_required([:name, :email, :password])
    |> validate_name()
    |> validate_email()
    |> validate_password()
    |> put_password_hash()
  end

  defp validate_name(changeset) do
    changeset
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 255, message: "must be between 1 and 255 characters")
  end

  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(
      :email,
      ~r/^[^@]+@[^@]+\.[^@]+$/,
      message: "Must be a valid email"
    )
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, Sortio.Repo)
    |> unique_constraint(:email)
  end

  defp validate_password(changeset) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
  end

  defp put_password_hash(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: password}} ->
        put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))

      _ ->
        changeset
    end
  end
end
