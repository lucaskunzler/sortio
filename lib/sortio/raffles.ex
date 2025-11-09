defmodule Sortio.Raffles do
  @moduledoc """
  Context module for raffle management.

  Provides functions to create, read, update, and delete raffles,
  along with helper functions for filtering and ownership checks.
  """
  import Ecto.Query

  alias Sortio.Repo
  alias Sortio.Raffles.Raffle
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
end
