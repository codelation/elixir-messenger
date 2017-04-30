defmodule Messenger.Router do
  use Plug.Router
  require Logger

  plug(Plug.Logger)


  plug Plug.Parsers, parsers: [:json],
                     pass:  ["text/*"],
                     json_decoder: Poison

  plug(:match)
  plug(:dispatch)

  post "/:task" do
    case Messenger.AuthorizePlug.call(conn, %{}) do
      %Plug.Conn{state: :sent} -> conn
      conn ->
        case Application.get_env(:messenger, :task_module).handle(task, conn.body_params) do
          {:ok, resp} -> send_unless(conn, 200, resp)
          {:error, resp} -> send_unless(conn, 500, resp)
          resp -> send_unless(conn, 500, %{error: "Invalid return value from task", task: task, response: resp})
        end
    end
  end

  defp send_unless(%{state: :sent} = conn, _code, _message), do: conn

  defp send_unless(conn, code, message) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(code, Poison.encode!(message))
  end
end
