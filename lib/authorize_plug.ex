defmodule Messenger.AuthorizePlug do
  import Plug.Conn
  require Logger

  def init(options), do: options

  def call(conn, _opts) do
    case find_token(conn) do
      {:ok, :valid} -> conn
      _otherwise   -> auth_error!(conn)
    end
  end

  defp find_token(conn) do
    with {:ok, req_token} <- get_token(conn),
      true <- validate_token(req_token),
    do: {:ok, :valid}
  end

  defp get_token(conn) do
    get_token_from_header(get_req_header(conn, "authorization"))
  end

  defp get_token_from_header(["Bearer " <> token]) do
    {:ok, String.replace(token, ~r/(\"|\')/, "")}
  end

  defp get_token_from_header(_non_token_header) do
    :error
  end

  defp validate_token(token) do
    Application.get_env(:messenger, :api_token) == token
  end

  defp auth_error!(conn) do
    Logger.debug "Invalid Token"
    conn
    |> put_status(:unauthorized)
    |> send_resp(401, Poison.encode!(%{error: "Invalid Token"}))
  end
end
