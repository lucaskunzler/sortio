defmodule Sortio.Raffles do
  @moduledoc """
  Context module for raffle management.

  Provides functions to create, read, update, and delete raffles,
  along with helper functions for filtering and ownership checks.
  """
  import Ecto.Query

  alias Sortio.Repo
  alias Sortio.Raffles.Raffle
  alias Sortio.ContextHelpers

  @default_page_size 20
  @max_page_size 100

  def list_raffles(opts \\ []) do
    page = max(Keyword.get(opts, :page, 1), 1)
    page_size = opts[:page_size] || @default_page_size
    page_size = min(page_size, @max_page_size)

    query =
      Raffle
      |> maybe_filter_by_status(opts[:status])
      |> order_by([r], desc: r.inserted_at)

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

  def get_raffle(id) do
    case Repo.get(Raffle, id) do
      nil -> {:error, :not_found}
      raffle -> {:ok, Repo.preload(raffle, :creator)}
    end
  end

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

  def delete_raffle(raffle) do
    ContextHelpers.with_logging(
      fn -> Repo.delete(raffle) end,
      "Raffle deleted successfully",
      "Raffle deletion failed",
      raffle_id: raffle.id
    )
  end

  def user_owns_raffle?(raffle, user) do
    raffle.creator_id == user.id
  end

  defp maybe_filter_by_status(query, status) when is_binary(status) do
    where(query, [r], r.status == ^status)
  end

  defp maybe_filter_by_status(query, _), do: query
end
