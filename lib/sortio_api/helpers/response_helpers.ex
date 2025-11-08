defmodule SortioApi.Helpers.ResponseHelpers do
  @moduledoc """
  Helper functions for API responses
  """

  import Plug.Conn

  def send_json(conn, status, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(data))
  end

  def send_success(conn, data, status \\ 200) do
    send_json(conn, status, data)
  end

  def send_error(conn, error, status \\ 400) do
    send_json(conn, status, %{"error" => format_error(error)})
  end

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
