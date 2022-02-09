defmodule <%= inspect context.base_module %>.Event.UserAdded do
  @derive Jason.Encoder
  defstruct [:stream_id, :email]
end


