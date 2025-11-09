defmodule SortioApi.Views.UserView do
  @moduledoc """
  View functions for rendering user data in API responses.
  """

  alias Sortio.Accounts.User

  @type user_json :: %{
          id: Ecto.UUID.t(),
          name: String.t(),
          email: String.t(),
          inserted_at: DateTime.t()
        }

  @type user_minimal_json :: %{
          id: Ecto.UUID.t(),
          name: String.t()
        }

  @spec render_user(User.t()) :: user_json()
  @doc """
  Renders a user for public API consumption.
  Excludes sensitive fields like password_hash.
  """
  def render_user(%User{} = user) do
    %{
      id: user.id,
      name: user.name,
      email: user.email,
      inserted_at: user.inserted_at
    }
  end

  @spec render_user_minimal(User.t()) :: user_minimal_json()
  @doc """
  Renders a minimal user (for nested resources like raffle creator).
  """
  def render_user_minimal(%User{} = user) do
    %{
      id: user.id,
      name: user.name
    }
  end
end
