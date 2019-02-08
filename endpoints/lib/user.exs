require Logger

alias Romeo.Stanza
alias Romeo.Connection, as: Conn

Logger.configure(level: :info)

bob_jid = "bob@localhost"
bob_pass = "bob"

alice_jid = "alice@localhost"
alice_pass = "alice"

sender = %{}
receiver = %{}

# Decide if we play as Bob or Alice
role = IO.gets("Are you Bob or Alice? (type `b` or `a`): ")
cond do
  String.starts_with?(String.downcase(role), "b") ->
    sender = %{jid: bob_jid, pass: bob_pass}
    receiver = %{jid: alice_jid, pass: alice_pass}
  true ->
    sender = %{jid: alice_jid, pass: alice_pass}
    receiver = %{jid: bob_jid, pass: bob_pass}
end

# Start the client
opts = [jid: sender[:jid], password: sender[:pass], port: 55222]
{:ok, pid} = Conn.start_link(opts)

# Send presence to the server
:ok = Conn.send(pid, Stanza.presence)

# Helpers

get_user_command = fn(parent, fun) ->
  command = IO.gets("Type a message to #{receiver[:jid]} (or `exit`): ")
  cond do
    String.starts_with?(String.downcase(command), "exit") ->
      send(parent, {:user_cmd, self(), :exit})
    is_binary(command) ->
      send(parent, {:user_cmd, self(), {:message, command}})
  end
  fun.(parent, fun)
end

handle_stanza =
  fn(_conn, %Romeo.Stanza.Presence{} = stanza) ->
    Logger.debug("[x] Received presence stanza=#{inspect stanza}")
  (_conn, %Romeo.Stanza.Message{} = stanza) ->
    Logger.info("[x] Received message=#{inspect stanza.body}" <>
      " from=#{inspect stanza.from.user}")
  (_conn, stanza) ->
      Logger.info("[x] Received stanza=#{inspect stanza}")
  end

handle_cmd =
  fn(conn, :exit) ->
    Conn.close(conn)
    Logger.info("Received `exit` request")
    exit(:normal)
  (conn, {:message, message}) ->
    Conn.send(conn, Stanza.chat(receiver[:jid], message))
  end

user_loop = fn(conn, cmd_handler, fun) ->
  receive do
    {:user_cmd, ^cmd_handler, cmd} ->
      handle_cmd.(conn, cmd)
    {:stanza, stanza} ->
      handle_stanza.(conn, stanza)
    other ->
      Logger.debug("Received other=#{inspect other}")
  end
  fun.(conn, cmd_handler, fun)
end

# Start the script
me = self()
cmd_handler_pid = spawn_link(fn -> get_user_command.(me, get_user_command) end)
user_loop.(pid, cmd_handler_pid, user_loop)
