defmodule Mix.Tasks.PrintCxModules do
  use Mix.Task

  @shortdoc "Simply runs the Hello.say/0 command."
  def run(_) do
    IO.puts("System command and aggregates are")

    with {:ok, list} <- :application.get_key(:cx_new, :modules) do
      list
      |> Enum.filter(&(&1 |> Module.split() |> Enum.take(1) == ~w|Command|))
      |> Enum.map(fn command ->
        IO.inspect(
          "#{command} -> #{CommandDispatcher.getStreamId(struct(command))} ->  #{CommandDispatcher.getAggregate(struct(command))}"
        )
      end)
    end

    IO.puts("System events are")

    with {:ok, list} <- :application.get_key(:cx_new, :modules) do
      list
      |> Enum.filter(&(&1 |> Module.split() |> Enum.take(1) == ~w|Event|))
      |> IO.inspect()
    end

    IO.puts("EventHandlers are")

    with {:ok, list} <- :application.get_key(:cx_new, :modules) do
      list
      |> Enum.filter(&(&1 |> Module.split() |> Enum.take(1) == ~w|EventHandler|))
      |> Enum.map(fn eventhandler ->
        IO.inspect("eventhandler: #{eventhandler}, handled_events:  #{inspect(eventhandler.interested_in())} ")
      end)
    end
  end
end
