require Logger
alias AMQP.{Connection, Channel, Queue}

Logger.configure(level: :info)

{:ok, conn} = Connection.open(host: "localhost", port: 55672)
{:ok, chann} = Channel.open(conn)
Logger.info("* Opened channel on connection=localhost:55672")

{:ok, %{queue: queue}} = Queue.declare(chann, "", exclusive: true)
Logger.info("* Declared queue=#{queue}")

:ok = Queue.bind(chann, queue, "presence", routing_key: "#")
:ok = Queue.bind(chann, queue, "chat_msg", routing_key: "#")

AMQP.Basic.consume(chann, queue)
Logger.info("* Consume from queue=#{queue}")

wait_for_messages = fn(channel, fun) ->
  receive do
    {:basic_deliver, payload, meta} ->
      Logger.info "[x] Received message=\"#{payload}\", routing_key=\"#{meta.routing_key}\""
      fun.(channel, fun)
  end
end

wait_for_messages.(chann, wait_for_messages)
