defmodule Aggregate do
  defmacro __using__(opts) do
    quote do
      use GenServer
      require Logger

      def start_link(args) do
        [stream_id: stream_id, name: name] = args
        GenServer.start_link(__MODULE__, [CxNewWeb.CanvasLive.module_to_string(__MODULE__) <> ":" <> stream_id], name: name)
      end

      def execute(command) do
        {:ok, pid} = find_or_start_aggregate_agent(command.stream_id)
        GenServer.call(pid, {:execute, command})
      end

      def init([stream_id]) do
        GenServer.cast(self(), :finish_init)
        {:ok, {stream_id, nil, 0}}
      end

      def handle_cast(:finish_init, {stream_id, nil, 0}) do
        events = []
        state = Enum.reduce(events, nil, fn event, state -> apply_event(state, event) end)
        {:noreply, {stream_id, state, length(events)}}
      end

      def handle_call(
            {:execute, command},
            _from,
            {stream_id, state, event_nr}
          ) do
        with {:ok, event} <- execute(command, state),
             _ <- IO.inspect(event),
             spear_event <-
               Spear.Event.new(CxNewWeb.CanvasLive.module_to_string(event.__struct__), Jason.encode!(event)),
             :ok <- Spear.append([spear_event], CxNew.EventStoreDbClient, stream_id) do
          new_state = apply_event(state, event)
          {:reply, :ok, {stream_id, new_state, event_nr + 1}}
        else
          err ->
            Logger.error("Something went wrong writing event #{inspect(err)}")
            {:reply, err, {stream_id, state, event_nr}}
        end
      end

      def find_or_start_aggregate_agent(stream_id) do
        Registry.lookup(AggregateRegistry, stream_id)
        |> case do
          [{pid, _}] ->
            {:ok, pid}

          [] ->
            spec = {__MODULE__, stream_id: stream_id, name: {:via, Registry, {AggregateRegistry, stream_id}}}
            DynamicSupervisor.start_child(AggregateSupervisor, spec)
        end
      end
    end
  end
end
