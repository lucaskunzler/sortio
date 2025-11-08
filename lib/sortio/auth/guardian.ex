defmodule Sortio.Auth.Guardian do
  @moduledoc """
  Guardian implementation for JWT-based authentication.

  Handles token generation and verification for authenticated users.
  """
  use Guardian, otp_app: :sortio

  alias Sortio.Accounts

  @doc """
  Encodes the user ID into the JWT token's subject claim.
  """
  def subject_for_token(%{id: id}, _claims) do
    {:ok, to_string(id)}
  end

  def subject_for_token(_, _) do
    {:error, :no_id}
  end

  @doc """
  Retrieves the user from the JWT token's subject claim.
  """
  def resource_from_claims(%{"sub" => id}) do
    case Accounts.get_user(id) do
      nil -> {:error, :user_not_found}
      user -> {:ok, user}
    end
  end

  def resource_from_claims(_claims) do
    {:error, :invalid_claims}
  end
end
