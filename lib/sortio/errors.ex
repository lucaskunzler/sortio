defmodule Sortio.Errors do
  @moduledoc """
  Standardized error atoms used across contexts.

  All context functions should return {:error, atom()} or {:error, Ecto.Changeset.t()}
  Controllers are responsible for translating atoms to user-friendly messages.
  """

  # Authentication errors
  @type auth_error :: :invalid_credentials | :user_not_found | :invalid_token

  # Resource errors
  @type resource_error :: :not_found | :forbidden | :already_exists

  # Validation errors
  @type validation_error :: :invalid_uuid | :invalid_params | Ecto.Changeset.t()

  # All possible errors
  @type error :: auth_error() | resource_error() | validation_error()

  @doc """
  Returns true if the error is an atom error (not a changeset).
  """
  @spec atom_error?(term()) :: boolean()
  def atom_error?(error) when is_atom(error), do: true
  def atom_error?(%Ecto.Changeset{}), do: false
  def atom_error?(_), do: false
end
