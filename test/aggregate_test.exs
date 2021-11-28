

defmodule TestCommand.Increment do
  defstruct[:stream_id]
end

defmodule Aggregate.Counter do
  use Aggregate
  defstruct [:value]

  def execute(%TestCommand.Increment{}, nil), do: %{value: 1}
  def execute(%TestCommand.Increment{}, %{value: x}), do: %{value: x+1
  end


end



defimpl CommandDispatcher for: TestCommand.Increment do
  :ok = Aggrgate.Counter.dispatch(



defmodule AggregateTest do
    use ExUnit.Case


  test "" do
    assert Example.hello() == :world
  end

 end
