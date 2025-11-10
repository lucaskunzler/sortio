defmodule Sortio.Raffles do
  @moduledoc """
  Context module for raffle management.

  Provides functions to create, read, update, and delete raffles,
  along with helper functions for filtering and ownership checks.
  """
  import Ecto.Query

  alias Sortio.Repo
  alias Sortio.Raffles.Raffle
  alias Sortio.Raffles.Participant
  alias Sortio.Accounts.User
  alias Sortio.ContextHelpers
  alias Sortio.Pagination

  @type pagination_result :: Pagination.pagination_result(Raffle.t())

  @spec list_raffles(keyword()) :: pagination_result()
  def list_raffles(opts \\ []) do
    from(r in Raffle)
    |> maybe_filter_by_status(opts[:status])
    |> order_by([r], desc: r.id)
    |> Pagination.paginate_with_preload(:creator, opts)
  end

  @spec get_raffle(Ecto.UUID.t()) :: {:ok, Raffle.t()} | {:error, :not_found}
  def get_raffle(id) do
    case Repo.get(Raffle, id) do
      nil -> {:error, :not_found}
      raffle -> {:ok, Repo.preload(raffle, :creator)}
    end
  end

  @spec create_raffle(map(), Ecto.UUID.t()) ::
          {:ok, Raffle.t()} | {:error, Ecto.Changeset.t()} | {:error, term()}
  def create_raffle(attrs, creator_id) do
    ContextHelpers.with_logging(
      fn ->
        Repo.transaction(fn ->
          with {:ok, raffle} <-
                 %Raffle{}
                 |> Raffle.create_changeset(attrs, creator_id)
                 |> Repo.insert(),
               {:ok, _job} <-
                 %{raffle_id: raffle.id}
                 |> Sortio.Workers.DrawWorker.new(scheduled_at: raffle.draw_date)
                 |> Oban.insert() do
            raffle
          else
            {:error, %Ecto.Changeset{} = changeset} ->
              Repo.rollback(changeset)

            {:error, reason} ->
              Repo.rollback(reason)
          end
        end)
      end,
      "Raffle created successfully",
      "Raffle creation failed",
      creator_id: creator_id
    )
  end

  @spec update_raffle(Raffle.t(), map()) ::
          {:ok, Raffle.t()} | {:error, Ecto.Changeset.t()}
  def update_raffle(raffle, attrs) do
    ContextHelpers.with_logging(
      fn ->
        raffle
        |> Raffle.update_changeset(attrs)
        |> Repo.update()
      end,
      "Raffle updated successfully",
      "Raffle update failed",
      raffle_id: raffle.id
    )
  end

  @spec delete_raffle(Raffle.t()) :: {:ok, Raffle.t()} | {:error, Ecto.Changeset.t()}
  def delete_raffle(raffle) do
    ContextHelpers.with_logging(
      fn -> Repo.delete(raffle) end,
      "Raffle deleted successfully",
      "Raffle deletion failed",
      raffle_id: raffle.id
    )
  end

  @spec user_owns_raffle?(Raffle.t(), User.t()) :: boolean()
  def user_owns_raffle?(raffle, user) do
    raffle.creator_id == user.id
  end

  @spec maybe_filter_by_status(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  defp maybe_filter_by_status(query, status) when is_binary(status) do
    where(query, [r], r.status == ^status)
  end

  defp maybe_filter_by_status(query, _), do: query

  @spec join_raffle(Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, Participant.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :not_found}
          | {:error, :raffle_closed}
          | {:error, :draw_date_passed}
          | {:error, :already_participating}
  @doc """
  Adds a user as a participant to a raffle.

  ## Parameters
    - raffle_id: The UUID of the raffle to join
    - user_id: The UUID of the user joining the raffle

  ## Returns
    - {:ok, participant} if successful
    - {:error, changeset} if validation fails
    - {:error, :already_participating} if user already joined
    - {:error, :not_found} if raffle doesn't exist
    - {:error, :raffle_closed} if raffle is closed
  """
  def join_raffle(raffle_id, user_id) do
    with {:ok, raffle} <- get_raffle(raffle_id),
         :ok <- validate_raffle_open(raffle) do
      result =
        ContextHelpers.with_logging(
          fn ->
            %Participant{}
            |> Participant.create_changeset(%{raffle_id: raffle_id, user_id: user_id})
            |> Repo.insert()
          end,
          "User joined raffle successfully",
          "Failed to join raffle",
          raffle_id: raffle_id,
          user_id: user_id
        )

      case result do
        {:error, %Ecto.Changeset{errors: errors} = changeset} ->
          # Check if it's a unique constraint violation
          if Keyword.has_key?(errors, :user_id) do
            {:error, :already_participating}
          else
            {:error, changeset}
          end

        other ->
          other
      end
    end
  end

  defp validate_raffle_open(%Raffle{status: "open", draw_date: draw_date}) do
    if DateTime.compare(DateTime.utc_now(), draw_date) == :lt do
      :ok
    else
      {:error, :draw_date_passed}
    end
  end

  defp validate_raffle_open(_raffle), do: {:error, :raffle_closed}

  @spec leave_raffle(Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, Participant.t()} | {:error, :participant_not_found}
  @doc """
  Removes a user from a raffle's participants.

  ## Parameters
    - raffle_id: The UUID of the raffle to leave
    - user_id: The UUID of the user leaving the raffle

  ## Returns
    - {:ok, participant} if successful
    - {:error, :participant_not_found} if participation doesn't exist
  """
  def leave_raffle(raffle_id, user_id) do
    query =
      from(p in Participant,
        where: p.raffle_id == ^raffle_id and p.user_id == ^user_id
      )

    case Repo.one(query) do
      nil ->
        {:error, :participant_not_found}

      participant ->
        ContextHelpers.with_logging(
          fn -> Repo.delete(participant) end,
          "User left raffle successfully",
          "Failed to leave raffle",
          raffle_id: raffle_id,
          user_id: user_id
        )
    end
  end

  @type participant_pagination_result :: Pagination.pagination_result(Participant.t())

  @spec list_participants(Ecto.UUID.t(), keyword()) :: participant_pagination_result()
  @doc """
  Lists all participants for a given raffle with pagination.

  ## Parameters
    - raffle_id: The UUID of the raffle
    - opts: Keyword list with pagination options
      - :page - The page number (default: 1)
      - :page_size - Number of items per page (default: 20, max: 100)

  ## Returns
    - Paginated result with participants and pagination metadata
  """
  def list_participants(raffle_id, opts \\ []) do
    from(p in Participant,
      where: p.raffle_id == ^raffle_id,
      order_by: [desc: p.id]
    )
    |> Pagination.paginate_with_preload(:user, opts)
  end

  @spec get_participant_count(Ecto.UUID.t()) :: non_neg_integer()
  @doc """
  Returns the count of participants for a raffle.

  ## Parameters
    - raffle_id: The UUID of the raffle

  ## Returns
    - The number of participants
  """
  def get_participant_count(raffle_id) do
    from(p in Participant,
      where: p.raffle_id == ^raffle_id,
      select: count(p.id)
    )
    |> Repo.one()
  end

  @spec user_participating?(Ecto.UUID.t(), Ecto.UUID.t()) :: boolean()
  @doc """
  Checks if a user is participating in a raffle.

  ## Parameters
    - raffle_id: The UUID of the raffle
    - user_id: The UUID of the user

  ## Returns
    - true if user is participating, false otherwise
  """
  def user_participating?(raffle_id, user_id) do
    query =
      from(p in Participant,
        where: p.raffle_id == ^raffle_id and p.user_id == ^user_id
      )

    Repo.exists?(query)
  end

  @doc """
  Draws a random winner for a raffle using atomic status update.

  Only raffles with status "open" can be drawn. Uses atomic UPDATE
  to prevent concurrent draws - only one process can successfully
  change status from "open" to "drawing".

  ## Returns
    - {:ok, raffle} if winner drawn successfully
    - {:ok, :already_claimed} if raffle already drawn or doesn't exist
    - {:error, changeset} if update fails
  """
  @spec draw_winner(Ecto.UUID.t()) ::
          {:ok, Raffle.t()} | {:ok, :already_claimed} | {:error, term()}
  def draw_winner(raffle_id) do
    claimed_count =
      from(r in Raffle,
        where: r.id == ^raffle_id and r.status == "open"
      )
      |> Repo.update_all(set: [status: "drawing"])

    case claimed_count do
      {0, _} ->
        case Repo.get(Raffle, raffle_id) do
          nil -> {:error, :not_found}
          _raffle -> {:ok, :already_claimed}
        end

      {1, _} ->
        raffle = Repo.get(Raffle, raffle_id)
        winner_id = get_random_participant_user_id(raffle_id)

        raffle
        |> Raffle.draw_changeset(winner_id)
        |> Repo.update()
    end
  end

  defp get_random_participant_user_id(raffle_id) do
    from(p in Participant,
      where: p.raffle_id == ^raffle_id,
      order_by: fragment("RANDOM()"),
      limit: 1,
      select: p.user_id
    )
    |> Repo.one()
  end
end
