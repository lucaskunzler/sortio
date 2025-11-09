defmodule Sortio.ContextHelpers do
  @moduledoc """
  Shared helper functions for context modules.

  Provides common patterns for logging and error handling across
  different context modules.
  """

  require Logger

  @type operation :: (-> {:ok, term()} | {:error, term()})
  @doc """
  Wraps a repository operation with success/error logging.

  ## Parameters
    - operation: A function that returns {:ok, result} or {:error, changeset}
    - success_message: Log message for successful operation
    - error_message: Log message for failed operation
    - metadata: Keyword list of additional metadata to log

  ## Examples

      with_logging(
        fn -> Repo.insert(changeset) end,
        "User created successfully",
        "User creation failed",
        user_id: user.id
      )
  """
  @spec with_logging(operation(), String.t(), String.t(), keyword()) ::
          {:ok, term()} | {:error, term()}
  def with_logging(operation, success_message, error_message, metadata \\ []) do
    case operation.() do
      {:ok, result} ->
        Logger.info(success_message, metadata)
        {:ok, result}

      {:error, error} ->
        error_details =
          case error do
            %Ecto.Changeset{} -> inspect(error.errors)
            other -> inspect(other)
          end

        Logger.warning(error_message, Keyword.merge(metadata, errors: error_details))
        {:error, error}
    end
  end
end
