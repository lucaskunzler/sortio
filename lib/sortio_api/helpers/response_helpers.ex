defmodule SortioApi.Helpers.ResponseHelpers do
  @moduledoc """
  Helper functions for API responses
  """

  import Plug.Conn

  @type json_data :: map() | list() | nil

  @spec send_json(Plug.Conn.t(), pos_integer(), json_data()) :: Plug.Conn.t()
  def send_json(conn, status, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(data))
  end

  @spec send_success(Plug.Conn.t(), map(), pos_integer()) :: Plug.Conn.t()
  def send_success(conn, data, status \\ 200) do
    send_json(conn, status, data)
  end

  @spec send_error(Plug.Conn.t(), term(), pos_integer()) :: Plug.Conn.t()
  def send_error(conn, error, status \\ 400) do
    send_json(conn, status, %{"error" => format_error(error)})
  end

  @spec format_error(term()) :: String.t()
  defp format_error(%Ecto.Changeset{} = changeset) do
    changeset.errors
    |> Enum.map(fn {field, {msg, _opts}} ->
      "#{field}: #{msg}"
    end)
    |> case do
      [] -> "Validation failed"
      errors -> Enum.join(errors, "; ")
    end
  end

  defp format_error(error) when is_binary(error), do: error
  defp format_error(error), do: inspect(error)
end
