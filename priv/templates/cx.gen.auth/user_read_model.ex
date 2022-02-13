defmodule <%= inspect context.base_module %>.ReadModel.AuthUser do
  use ReadModel

  def handle_event({%<%= inspect context.base_module %>.Event.UserAdded{} = event, metadata}) do
    state = get(event.stream_id)
    update_read_model_and_bookmark(event.stream_id, %{id: event.stream_id, email: event.email}, metadata)
  end

  def get_by_email(email) do
		[{{:"$1", %{email: :"$2"}}, [{:==, :"$2", email}], [:"$1"]}]
		|> select()
  end

  def handle_event({_, metadata}), do: update_bookmark(metadata)



end
