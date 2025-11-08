defmodule Sortio.Accounts do
  @moduledoc """
  The Accounts context handles user management and authentication.
  """
  alias Sortio.Repo
  alias Sortio.Accounts.User

  def get_user(id), do: Repo.get(User, id)

  def register_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end
end
