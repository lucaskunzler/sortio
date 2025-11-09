defmodule Sortio.Pagination do
  @moduledoc """
  Reusable pagination utilities for contexts.

  Provides helper functions for paginating Ecto queries with consistent
  pagination metadata including total counts and page information.
  """

  import Ecto.Query
  alias Sortio.Repo

  @default_page 1
  @default_page_size 20
  @max_page_size 100

  @type pagination_result(entry_type) :: %{
          entries: [entry_type],
          page: pos_integer(),
          page_size: pos_integer(),
          total_count: non_neg_integer(),
          total_pages: non_neg_integer()
        }

  @type pagination_opts :: [
          page: pos_integer(),
          page_size: pos_integer()
        ]

  @doc """
  Paginates an Ecto query.

  ## Parameters
    - query: The Ecto query to paginate
    - opts: Keyword list with pagination options
      - :page - The page number (default: 1, minimum: 1)
      - :page_size - Number of items per page (default: 20, max: 100)

  ## Returns
    A map containing:
    - :entries - The paginated list of records
    - :page - Current page number
    - :page_size - Number of items per page
    - :total_count - Total number of records
    - :total_pages - Total number of pages

  ## Examples

      iex> query = from(u in User)
      iex> Sortio.Pagination.paginate(query, page: 1, page_size: 10)
      %{
        entries: [...],
        page: 1,
        page_size: 10,
        total_count: 42,
        total_pages: 5
      }
  """
  @spec paginate(Ecto.Query.t(), pagination_opts()) :: pagination_result(any())
  def paginate(query, opts \\ []) do
    page = max(Keyword.get(opts, :page, @default_page), 1)
    page_size = opts[:page_size] || @default_page_size
    page_size = min(page_size, @max_page_size)

    total_count = Repo.aggregate(query, :count)
    total_pages = ceil(total_count / page_size)

    entries =
      query
      |> limit(^page_size)
      |> offset(^((page - 1) * page_size))
      |> Repo.all()

    %{
      entries: entries,
      page: page,
      page_size: page_size,
      total_count: total_count,
      total_pages: total_pages
    }
  end

  @doc """
  Paginates an Ecto query with preloading.

  Same as `paginate/2` but also preloads associations on the entries.

  ## Parameters
    - query: The Ecto query to paginate
    - preloads: Associations to preload (same format as Repo.preload)
    - opts: Keyword list with pagination options (same as paginate/2)

  ## Examples

      iex> query = from(r in Raffle)
      iex> Sortio.Pagination.paginate_with_preload(query, :creator, page: 1)
      %{entries: [...], page: 1, ...}

      iex> query = from(p in Participant)
      iex> Sortio.Pagination.paginate_with_preload(query, [:user, :raffle], page: 2)
      %{entries: [...], page: 2, ...}
  """
  @spec paginate_with_preload(Ecto.Query.t(), atom() | list(), pagination_opts()) ::
          pagination_result(any())
  def paginate_with_preload(query, preloads, opts \\ []) do
    result = paginate(query, opts)
    %{result | entries: Repo.preload(result.entries, preloads)}
  end

  @doc """
  Returns default page size.
  """
  @spec default_page_size() :: pos_integer()
  def default_page_size, do: @default_page_size

  @doc """
  Returns maximum page size.
  """
  @spec max_page_size() :: pos_integer()
  def max_page_size, do: @max_page_size
end
