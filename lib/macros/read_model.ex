defmodule ReadModel do
  defmacro __using__(opts) do
    quote do
      use GenServer
      require Logger

      def subscribe(id) do
        Phoenix.PubSub.subscribe(CxNew.PubSub, to_string(__MODULE__) <> ":" <> id)
      end

      def subscribe_to_all() do
        Phoenix.PubSub.subscribe(CxNew.PubSub, to_string(__MODULE__))
      end

      def broadcast(id, state) do
        Phoenix.PubSub.broadcast(CxNew.PubSub, to_string(__MODULE__) <> ":" <> id, {__MODULE__, id, state})
      end

      def broadcast_to_all(id, state) do
        Phoenix.PubSub.broadcast(CxNew.PubSub, to_string(__MODULE__), {__MODULE__, id, state})
      end

      def start_link(args) do
        GenServer.start_link(__MODULE__, [], name: __MODULE__)
      end

      def init([]) do
        :ets.new(__MODULE__, [:set, :named_table, :public])
        :dets.open_file(__MODULE__, [])
        last_event = get_last_event()
        {:ok, sub} = subscribe_all(:start)
        {:ok, %{}}
      end

      def get(id) do
        :ets.lookup(__MODULE__, id)
        |> case do
          [] -> nil
          [{_id, data}] -> data
        end
      end

      def get_all() do
        :ets.tab2list(__MODULE__)
        |> Enum.filter(fn {key, elem} -> String.contains?(key, "bookmark") == false end)
        |> Enum.map(fn {key, elem} -> elem end)
      end

      def get_bookmark(stream_name) do
        IO.puts("getting bookmark from stream_name")
        IO.inspect(stream_name)

        :ets.lookup(__MODULE__, "bookmark:#{inspect stream_name}")
        |> case do
          [{_id, number}] ->
            number

          [] ->
            :dets.lookup(__MODULE__, "bookmark:#{inspect stream_name}")
            |> case do
              [] ->
                nil

              [{_id, number}] ->
                :ets.insert(__MODULE__, {"bookmark:#{inspect stream_name}", number})
                number
            end
        end
      end

      def get_last_event(), do: :start

      def set(id, data, stream) do
        :ets.insert(__MODULE__, {id, data})
      end

      def select(fun) do
        :ets.select(__MODULE__, fun)
      end

      def update_read_model_and_bookmark(rm_id, rm_data, metadata),
        do: update_read_model_and_bookmark(rm_id, rm_data, metadata.stream_name, metadata.stream_revision)

      def update_read_model_and_bookmark(rm_id, rm_data, stream_name, revision) do
        :ets.insert(__MODULE__, [{rm_id, rm_data}, {"bookmark:#{inspect stream_name}", revision}])
        broadcast(rm_id, rm_data)
        broadcast_to_all(rm_id,rm_data)
        :ok
      end

      def update_bookmark(metadata) do
        true = :ets.insert(__MODULE__, [{"bookmark:#{inspect metadata.stream_name}", metadata.stream_revision}])
        :ok
      end

      defp subscribe_all(from),
        do:
          Spear.subscribe(CxNew.EventStoreDbClient, self(), :all,
            from: from,
            filter: Spear.Filter.exclude_system_events()
          )

      def handle_info(%Spear.Event{} = event, _state) do
        IO.puts("event is")
        IO.inspect(event)

        get_bookmark(event.metadata.stream_name)
        |> case do
          nil when event.metadata.stream_revision == 0 -> 0
          x when x + 1 == event.metadata.stream_revision -> x + 1
          x when x == event.metadata.stream_revision -> :already_handled
          x -> raise "bookmark is #{x} and stream revision is #{event.metadata.stream_revision} out of order"
        end
        |> case do
          :already_handled ->
            {:noreply, _state}

          new_revision ->
            {domain_event, metadata} = CxNew.Helpers.map_spear_event_to_domain_event(event)
            :ok = handle_event({domain_event, metadata})
            ## send event revision as a
        end

        {:noreply, _state}
      end

      def handle_info(_, state), do: {:noreply, state}
    end
  end
end
