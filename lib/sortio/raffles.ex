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

  @default_page_size 20
  @max_page_size 100

  @type pagination_result :: %{
          entries: [Raffle.t()],
          page: pos_integer(),
          page_size: pos_integer(),
          total_count: non_neg_integer(),
          total_pages: non_neg_integer()
        }

  @spec list_raffles(keyword()) :: pagination_result()
  def list_raffles(opts \\ []) do
    page = max(Keyword.get(opts, :page, 1), 1)
    page_size = opts[:page_size] || @default_page_size
    page_size = min(page_size, @max_page_size)

    query =
      from(r in Raffle)
      |> maybe_filter_by_status(opts[:status])
      |> order_by([r], desc: r.id)

    total_count = Repo.aggregate(query, :count, :id)
    total_pages = ceil(total_count / page_size)

    entries =
      query
      |> limit(^page_size)
      |> offset(^((page - 1) * page_size))
      |> Repo.all()
      |> Repo.preload(:creator)

    %{
      entries: entries,
      page: page,
      page_size: page_size,
      total_count: total_count,
      total_pages: total_pages
    }
  end

  @spec get_raffle(Ecto.UUID.t()) :: {:ok, Raffle.t()} | {:error, :not_found}
  def get_raffle(id) do
    case Repo.get(Raffle, id) do
      nil -> {:error, :not_found}
      raffle -> {:ok, Repo.preload(raffle, :creator)}
    end
  end

  @spec create_raffle(map(), Ecto.UUID.t()) ::
          {:ok, Raffle.t()} | {:error, Ecto.Changeset.t()}
  def create_raffle(attrs, creator_id) do
    ContextHelpers.with_logging(
      fn ->
        %Raffle{}
        |> Raffle.create_changeset(attrs, creator_id)
        |> Repo.insert()
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
  @doc """
  Adds a user as a participant to a raffle.

  ## Parameters
    - raffle_id: The UUID of the raffle to join
    - user_id: The UUID of the user joining the raffle

  ## Returns
    - {:ok, participant} if successful
    - {:error, changeset} if validation fails (e.g., already joined)
    - {:error, :not_found} if raffle doesn't exist
    - {:error, :raffle_closed} if raffle is closed
  """
  def join_raffle(raffle_id, user_id) do
    with {:ok, raffle} <- get_raffle(raffle_id),
         :ok <- validate_raffle_open(raffle) do
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
    end
  end

  @spec validate_raffle_open(Raffle.t()) :: :ok | {:error, :raffle_closed}
  defp validate_raffle_open(%Raffle{status: "open"}), do: :ok
  defp validate_raffle_open(%Raffle{status: "closed"}), do: {:error, :raffle_closed}

  @spec leave_raffle(Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, Participant.t()} | {:error, :not_found}
  @doc """
  Removes a user from a raffle's participants.

  ## Parameters
    - raffle_id: The UUID of the raffle to leave
    - user_id: The UUID of the user leaving the raffle

  ## Returns
    - {:ok, participant} if successful
    - {:error, :not_found} if participation doesn't exist
  """
  def leave_raffle(raffle_id, user_id) do
    query =
      from(p in Participant,
        where: p.raffle_id == ^raffle_id and p.user_id == ^user_id
      )

    case Repo.one(query) do
      nil ->
        {:error, :not_found}

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

  @spec list_participants(Ecto.UUID.t()) :: [Participant.t()]
  @doc """
  Lists all participants for a given raffle.

  ## Parameters
    - raffle_id: The UUID of the raffle

  ## Returns
    - List of participants with preloaded user data
  """
  def list_participants(raffle_id) do
    from(p in Participant,
      where: p.raffle_id == ^raffle_id,
      order_by: [desc: p.inserted_at]
    )
    |> Repo.all()
    |> Repo.preload(:user)
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
end
