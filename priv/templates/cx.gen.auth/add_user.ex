defmodule <%= inspect context.base_module %>.Command.AddUser  do
  defstruct [:stream_id, :email, :email_is_available]

  defimpl <%= inspect context.base_module %>.CommandDispatcher, for: <%= inspect context.base_module%>.Command.AddUser do
    def dispatch(command) do
      <%= inspect context.base_module %>.Aggregate.UserAggregate.execute(command)
    end
  end

end

