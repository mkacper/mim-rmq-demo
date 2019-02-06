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

recv_stanzas = fn(recv_fun) ->
  receive do
    {:stanza, stanza} ->
      Logger.info "[x] Received stanza=`#{inspect(stanza)}`"
      recv_fun.(recv_fun)
  after
    0 -> :no_more_stanzas
  end
end

send_msgs_and_recv_stanzas = fn(pid, fun) ->
  message = IO.gets("Type a message to #{receiver[:jid]} (or `exit` or `skip`): ")
  cond do
    String.starts_with?(String.downcase(message), "exit") ->
      Conn.close(pid)
      Logger.info("Received `exit` request")
      exit(:normal)
    String.starts_with?(String.downcase(message), "skip") ->
      :skip
    true ->
      Conn.send(pid, Stanza.chat(receiver[:jid], message))
  end
  recv_stanzas.(recv_stanzas)
  fun.(pid, fun)
end

# Start the script
send_msgs_and_recv_stanzas.(pid, send_msgs_and_recv_stanzas)
