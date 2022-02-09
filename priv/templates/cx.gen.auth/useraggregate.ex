defmodule <%= inspect context.base_module %>.Aggregate.UserAggregate do
  use Aggregate
  alias <%= inspect context.base_module %>.Command
  alias <%= inspect context.base_module %>.Event


  def execute(%Command.AddUser{stream_id: stream_id, email: email, email_is_available: "true"} = cmd, nil) do
  	{:ok, %Event.UserAdded{stream_id: stream_id, email: email}}
  end

  def execute(%Command.AddUser{stream_id: stream_id, email: email, email_is_available: email_is_available} = cmd, nil) do
  	{:error, :already_exists}
  end

  def execute(%Command.AddUser{stream_id: stream_id, email: email} = cmd, state) do
  	{:error, :already_exists}
  end

	def apply_event(nil,%Event.UserAdded{email: email}), do: %{email: email}
end
