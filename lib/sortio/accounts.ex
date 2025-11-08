defmodule Sortio.Accounts do
  @moduledoc """
  The Accounts context handles user management and authentication.
  """
  alias Sortio.Repo
  alias Sortio.Accounts.User

  def get_user(id), do: Repo.get(User, id)

  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  def register_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Authenticates a user with email and password.
  Returns {:ok, user} if credentials are valid, {:error, reason} otherwise.
  """
  def authenticate_user(email, password) do
    case get_user_by_email(email) do
      nil ->
        # Run bcrypt to prevent timing attacks
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}

      user ->
        if verify_password(password, user.password_hash) do
          {:ok, user}
        else
          {:error, :invalid_credentials}
        end
    end
  end

  defp verify_password(password, password_hash) do
    Bcrypt.verify_pass(password, password_hash)
  end
end
