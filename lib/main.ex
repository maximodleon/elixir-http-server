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

    accept_loop(socket)

    # :gen_tcp.close(client)
    # :gen_tcp.close(socket)
  end

  def accept_loop(socket) do
     {:ok, client} = :gen_tcp.accept(socket)

    spawn(fn ->
     {:ok, data } = :gen_tcp.recv(client, 0)
     handle_request(data, client)
    end)

    accept_loop(socket)
  end

  def handle_request(data, client_socket) do
    request_data = data
    |> get_request_line
    |> get_request_headers(data)
    |> get_request_body(data)

    handle_route(client_socket, request_data, request_data.method, request_data.path)
  end

  def get_request_line(request_data) do
    [method, path, _] = request_data
    |> String.split("\r\n")
    |> List.first
    |> String.split(" ")

    %{method: method, path: path, headers: [], body: ""}
  end

  def get_request_headers(request_map, request_data) do
    size = request_data
    |> String.split("\r\n")
    |> length

    headers = request_data
    |> String.split("\r\n")
    |> Enum.slice(1..size - 2)
    |> Enum.filter(fn x -> x != "" end)

    %{ request_map | headers: headers }
  end

  def get_request_body(request_map, request_data) do
    body =
      request_data
      |> String.split("\r\n")
      |> List.last

      %{request_map | body: body }
  end

  def handle_route(socket, _request_map, "GET", "/") do
     :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 0\r\nContent-Type: text/plain\r\n\r\n")
  end

  def handle_route(socket, request_map, "GET", "/echo/" <> echo_str) do
    content_encoding =
      request_map.headers
      |> Enum.find(fn x -> String.contains?(x, "Accept-Encoding") end)
      |> case do
        nil -> ""
        "" -> ""
        x -> x
            |> String.split(":")
            |> Enum.at(1)
            |> String.split(",")
            |> Enum.find(fn x -> String.trim(x, " ") == "gzip" end)
            |> case  do
              " gzip" -> "\r\nContent-Encoding: gzip"
                _ -> ""
            end
      end

      if (String.length(content_encoding) == 0) do
        :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length:#{String.length(echo_str)}#{content_encoding}\r\n\r\n#{echo_str}")
      else
         encoded_str = :zlib.gzip(echo_str)
        :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length:#{byte_size(encoded_str)}#{content_encoding}\r\n\r\n#{encoded_str}")
      end
  end

  def handle_route(socket, _request_map, "GET", "/files/" <> filename) do
     { parsed, _, _ } = OptionParser.parse(System.argv(), switches: [directory: :string])
     dirname = Enum.at(parsed, 0) |> elem(1)

     case File.read( dirname <> "/" <> filename) do
        {:ok, content } -> :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Length:#{String.length(content)}\r\n\r\n#{content}")
        {:error, :enoent} -> :gen_tcp.send(socket, "HTTP/1.1 404 Not Found\r\nContent-Type: application/octet-stream\r\nContent-Length:0\r\n\r\n")
     end
  end

  def handle_route(socket, _request_map, "GET", "/User-Agent/" <> user_agent_str ) do
      :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length:#{String.length(user_agent_str)}\r\n\r\n#{user_agent_str}")
  end

  def handle_route(socket, request_map, "POST", "/files/" <> filename ) do
     { parsed, _, _ } = OptionParser.parse(System.argv(), switches: [directory: :string])
     dirname = Enum.at(parsed, 0) |> elem(1)
     {:ok, file } = File.open( dirname <> "/" <> filename, [:write])
     IO.write(file, request_map.body)
     :gen_tcp.send(socket, "HTTP/1.1 201 Created\r\n\r\n")
     File.close(file)
  end

  def handle_route(socket, _request_map, _method, _path) do
     :gen_tcp.send(socket, "HTTP/1.1 404 Not Found\r\nContent-Length:0\r\nContent-Type: text/plain\r\n\r\n")
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
