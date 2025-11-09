defmodule SortioApi.Router do
  use Plug.Router

  alias Sortio.Accounts
  alias Sortio.Raffles
  alias Sortio.Auth.Guardian
  alias SortioApi.Helpers.ResponseHelpers

  import ResponseHelpers

  plug(Plug.Logger)
  plug(:match)

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason
  )

  plug(:dispatch)

  get "/health" do
    send_json(conn, 200, %{"status" => "ok"})
  end

  post "/users" do
    with {:ok, params} <- validate_user_params(conn.body_params),
         {:ok, user} <- Accounts.register_user(params) do
      send_success(conn, %{"user" => format_user(user)}, 201)
    else
      {:error, error} -> send_error(conn, error, 422)
    end
  end

  post "/login" do
    with {:ok, params} <- validate_login_params(conn.body_params),
         {:ok, user} <- Accounts.authenticate_user(params.email, params.password),
         {:ok, token, _claims} <- Guardian.encode_and_sign(user) do
      send_success(
        conn,
        %{
          "token" => token,
          "user" => format_user(user)
        },
        200
      )
    else
      {:error, :invalid_credentials} ->
        send_error(conn, "Invalid email or password", 401)

      {:error, error} ->
        send_error(conn, error, 400)
    end
  end

  get "/raffles" do
    status = conn.query_params["status"]
    page = parse_positive_integer(conn.query_params["page"], 1)
    page_size = parse_positive_integer(conn.query_params["page_size"], 20)

    query_opts = []
    query_opts = if status, do: [{:status, status} | query_opts], else: query_opts
    query_opts = [{:page, page}, {:page_size, page_size} | query_opts]

    result = Raffles.list_raffles(query_opts)

    send_success(
      conn,
      %{
        "raffles" => Enum.map(result.entries, &format_raffle/1),
        "pagination" => %{
          "page" => result.page,
          "page_size" => result.page_size,
          "total_count" => result.total_count,
          "total_pages" => result.total_pages
        }
      },
      200
    )
  end

  get "/raffles/:id" do
    with :ok <- validate_uuid(id),
         {:ok, raffle} <- fetch_raffle(id) do
      send_success(conn, %{"raffle" => format_raffle(raffle)}, 200)
    else
      {:error, :invalid_uuid} ->
        send_error(conn, "Invalid raffle ID format", 400)

      {:error, :not_found} ->
        send_error(conn, "Raffle not found", 404)
    end
  end

  post "/raffles" do
    with_authentication(conn, fn conn, user ->
      with {:ok, params} <- validate_raffle_params(conn.body_params),
           {:ok, raffle} <- Raffles.create_raffle(params, user.id) do
        send_success(conn, %{"raffle" => format_raffle(raffle)}, 201)
      else
        {:error, error} -> send_error(conn, error, 422)
      end
    end)
  end

  put "/raffles/:id" do
    with_authentication(conn, fn conn, user ->
      with :ok <- validate_uuid(id),
           {:ok, raffle} <- fetch_raffle(id),
           :ok <- authorize_raffle_owner(raffle, user),
           {:ok, updated_raffle} <- Raffles.update_raffle(raffle, conn.body_params) do
        send_success(conn, %{"raffle" => format_raffle(updated_raffle)}, 200)
      else
        {:error, :invalid_uuid} ->
          send_error(conn, "Invalid raffle ID format", 400)

        {:error, :not_found} ->
          send_error(conn, "Raffle not found", 404)

        {:error, :forbidden} ->
          send_error(conn, "You don't have permission to update this raffle", 403)

        {:error, error} ->
          send_error(conn, error, 422)
      end
    end)
  end

  delete "/raffles/:id" do
    with_authentication(conn, fn conn, user ->
      with :ok <- validate_uuid(id),
           {:ok, raffle} <- fetch_raffle(id),
           :ok <- authorize_raffle_owner(raffle, user),
           {:ok, _raffle} <- Raffles.delete_raffle(raffle) do
        send_json(conn, 204, nil)
      else
        {:error, :invalid_uuid} ->
          send_error(conn, "Invalid raffle ID format", 400)

        {:error, :not_found} ->
          send_error(conn, "Raffle not found", 404)

        {:error, :forbidden} ->
          send_error(conn, "You don't have permission to delete this raffle", 403)

        {:error, error} ->
          send_error(conn, error, 422)
      end
    end)
  end

  get "/me" do
    with_authentication(conn, fn conn, user ->
      send_success(conn, %{"user" => format_user(user)}, 200)
    end)
  end

  match _ do
    send_json(conn, 404, %{"error" => "Not found"})
  end

  defp with_authentication(conn, handler_fn) do
    case authenticate(conn) do
      %{halted: true} = conn ->
        conn

      conn ->
        user = conn.assigns.current_user
        handler_fn.(conn, user)
    end
  end

  defp validate_user_params(params) do
    with {:ok, name} <- Map.fetch(params, "name"),
         {:ok, email} <- Map.fetch(params, "email"),
         {:ok, password} <- Map.fetch(params, "password") do
      {:ok, %{name: name, email: email, password: password}}
    else
      :error -> {:error, "Missing required fields: name, email, password"}
    end
  end

  defp validate_login_params(params) do
    with {:ok, email} <- Map.fetch(params, "email"),
         {:ok, password} <- Map.fetch(params, "password") do
      {:ok, %{email: email, password: password}}
    else
      :error -> {:error, "Missing required fields: email, password"}
    end
  end

  defp authenticate(conn) do
    SortioApi.Plugs.Authenticate.call(conn, [])
  end

  defp format_user(user) do
    %{
      id: user.id,
      name: user.name,
      email: user.email,
      inserted_at: user.inserted_at
    }
  end

  defp validate_raffle_params(params) do
    title = Map.get(params, "title")

    if title do
      case parse_draw_date(Map.get(params, "draw_date")) do
        {:ok, draw_date} ->
          {:ok,
           %{
             title: title,
             description: Map.get(params, "description"),
             draw_date: draw_date
           }}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, "Missing required field: title"}
    end
  end

  defp parse_draw_date(nil), do: {:ok, nil}

  defp parse_draw_date(draw_date) when is_binary(draw_date) do
    case DateTime.from_iso8601(draw_date) do
      {:ok, datetime, _offset} ->
        {:ok, datetime}

      {:error, _} ->
        {:error, "Invalid date format. Expected ISO8601 format (e.g., 2024-01-01T12:00:00Z)"}
    end
  end

  defp parse_draw_date(_),
    do: {:error, "Invalid date format. Expected ISO8601 format (e.g., 2024-01-01T12:00:00Z)"}

  defp parse_positive_integer(nil, default), do: default

  defp parse_positive_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int > 0 -> int
      _ -> default
    end
  end

  defp parse_positive_integer(_, default), do: default

  defp validate_uuid(id) do
    case Ecto.UUID.cast(id) do
      {:ok, _uuid} -> :ok
      :error -> {:error, :invalid_uuid}
    end
  end

  defp format_raffle(raffle) do
    base = %{
      id: raffle.id,
      title: raffle.title,
      description: raffle.description,
      status: raffle.status,
      draw_date: raffle.draw_date,
      inserted_at: raffle.inserted_at,
      updated_at: raffle.updated_at
    }

    case raffle.creator do
      %Ecto.Association.NotLoaded{} ->
        base

      creator ->
        Map.put(base, :creator, %{
          id: creator.id,
          name: creator.name
        })
    end
  end

  defp fetch_raffle(id) do
    case Raffles.get_raffle(id) do
      nil -> {:error, :not_found}
      raffle -> {:ok, raffle}
    end
  end

  defp authorize_raffle_owner(raffle, user) do
    if Raffles.user_owns_raffle?(raffle, user) do
      :ok
    else
      {:error, :forbidden}
    end
  end
end
