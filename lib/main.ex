defmodule Server do
  use Application

  def start(_type, _args) do
    Supervisor.start_link([{Task, fn -> Server.listen() end}], strategy: :one_for_one)
  end

  def listen() do
    # You can use print statements as follows for debugging, they'll be visible when running tests.
    IO.puts("Logs from your program will appear here!")

    # # Since the tester restarts your program quite often, setting SO_REUSEADDR
    # # ensures that we don't run into 'Address already in use' errors
    {:ok, socket} = :gen_tcp.listen(4221, [:binary, active: false, reuseaddr: true])
    {:ok, client} = :gen_tcp.accept(socket)

    {:ok, data } = :gen_tcp.recv(client, 0)

    handle_request(data, client)
    :gen_tcp.close(client)
    :gen_tcp.close(socket)
  end

  def handle_request(data, client_socket) do
   data_enum = String.split(data, "\r\n")

     data_enum
    |> Enum.at(0)
    |> String.split(" ")
    |> Enum.at(0)
    |> case do
      "GET" -> handle_GET_request(client_socket, data_enum)
      _ -> :gen_tcp.send(client_socket, "HTTP/1.1 404 Not Found\r\n\r\n")
    end
  end

  def handle_GET_request(socket, data_enum) do
    route = data_enum
    |> Enum.at(0)
    |> String.split(" ")
    |> Enum.at(1)

    cond do
       String.match?(route, ~r/echo/) ->
          echo_str = route |> String.split("/") |> Enum.at(2)
          :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length:#{String.length(echo_str)}\r\n\r\n#{echo_str}")
       String.match?(route, ~r/User-Agent/i) ->
          user_agent_str =
           data_enum
            |> Enum.slice(1..Enum.count(data_enum))
            |> Enum.find(fn x -> String.match?(x, ~r/User-Agent/i) end)
            |> String.split(":")
            |> Enum.at(1)
            |> String.trim

          :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length:#{String.length(user_agent_str)}\r\n\r\n#{user_agent_str}")
       route == "/" ->
          :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 0\r\nContent-Type: text/plain\r\n\r\n")
        true ->
          :gen_tcp.send(socket, "HTTP/1.1 404 Not Found\r\nContent-Length:0\r\nContent-Type: text/plain\r\n\r\n")
    end
  end
end

defmodule CLI do
  def main(_args) do
    # Start the Server application
    {:ok, _pid} = Application.ensure_all_started(:codecrafters_http_server)

    # Run forever
    Process.sleep(:infinity)
  end
end
