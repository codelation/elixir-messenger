defmodule CodelationMessenger.Router do
  @moduledoc """
  Forward requests to this router by `forward "/message", to: Messenger.Router`.  This will capture
  POST requests on the `/message/:task` route calling the task specified.  In your config, you will need
  to add the following options:

  ```
  config :messenger,
    api_token: System.get_env("API_TOKEN"),
    task_module: YourTaskModule
  ```

  You will need to define a task module that has a `handle(message, data)` function.  This function
  needs to return either {:ok, %{}} or {:error, %{}}.  If not, this will automatically return a 500 error.

  You can send messages to this router by sending a `POST` request with a `JSON` body and an
  `Authorization Bearer token` header.

  """
  use Plug.Router
  require Logger

  plug(Plug.Logger)


  plug Plug.Parsers, parsers: [:json],
                     pass:  ["text/*"],
                     json_decoder: Poison

  plug(:match)
  plug(:dispatch)

  post "/:task" do
    case CodelationMessenger.Authorize.authorize(conn) do
      %Plug.Conn{state: :sent} -> conn
      conn ->
        case Application.get_env(:codelation_messenger, :task_module).handle(task, conn.body_params) do
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
