
defmodule CxNewWeb.AdminLive do
  use CxNewWeb, :live_view


  def mount(_params, _, socket) do
    streams = Spear.stream!(CxNew.EventStoreDbClient, "$streams") |> Enum.to_list() |> Enum.map(fn x -> x.metadata.stream_name end)
    IO.inspect streams
    Spear.stream!(CxNew.EventStoreDbClient, "$streams") |> Enum.count() |> IO.inspect()

     {:ok, list} = :application.get_key(:cx_new, :modules)
      commands = list
      |> Enum.filter(& &1 |> Module.split |> Enum.take(1) == ~w|Command|)

    {:ok, assign(socket, command: nil, streams: streams, checked: nil, events: [], commands: commands, modal_open: false)}
  end

  def handle_event("set_checked", %{"id" => stream_id}, socket) do
    case socket.assigns.checked do
      x when x == stream_id -> {:noreply, assign(socket, checked: nil, loading: false)}
      _ ->
        send(self(), {:get_events, stream_id})
      	{:noreply, assign(socket, checked: stream_id, loading: true)}
    end
  end

  def handle_event("toggle_modal", %{"command" => string_command}, socket) do
    {:noreply, assign(socket, modal_open: true, command: String.to_existing_atom(string_command))}
 end
  def handle_event("toggle_modal", %{}, socket) do
    {:noreply, assign(socket, modal_open: false)}
 end

  def handle_info({:get_events, stream_id}, socket) do
    events = Spear.stream!(CxNew.EventStoreDbClient, stream_id) |> Enum.to_list()
    {:noreply, assign(socket, loading: false, events: events)}
  end

  def render(assigns) do
    ~H"""
    <div class="p-10">
    	<div class="prose ">
        <h1 class=""> Admin Panel</h1>
    		<div class="py-5" >
        	<h3> Streams </h3>
            <%= for stream_id <- @streams do %>
              <button phx-click="set_checked" phx-value-id={stream_id} class=" w-full pb-2 border rounded-box border-base-300 collapse-arrow">
              	<div class=" text-left collapse-title text-xl font-medium">
                	<%= stream_id %>
                </div>
                <%= if stream_id == @checked do %>
                	<div class="px-5 text-left">
                		<%= if @loading do %>
                			<div class="btn btn-lg btn-ghost loading"> </div>
                		<% end %>
                		<ol >
                			<%= for event <- @events do %>
                 				<li> <a> <%= event.type %> </a> </li>
                 			<% end %>
                 		</ol>
                 	</div>
                <% end %>
              </button>
            <% end %>
        </div>

     <h3 class="py-5"> Dispatch a Command</h3>

<%= if @command do %>
<input type="checkbox" checked={@modal_open} class="modal-toggle" >
<div class="modal">
  <div class="modal-box">
  <h3> <%= to_string(@command) %> </h3>
  <form>
<div class="form-control">
  <%= for key <- Map.keys(Map.from_struct(@command)) do %>
  <label class="label">
    <span class="label-text"> <%= key %> </span>
  </label> 
  <input type="text" name={key}  class="input input-bordered">
  <% end %>
</div>
</form>

    <div class="modal-action">
      <label for="my-modal-2" class="btn btn-primary">Accept</label> 
      <label for="my-modal-2" class="btn" phx-click="toggle_modal" >Close</label>
    </div>
  </div>
</div>
<% end %>


     <%= for command <- @commands do %>
     <ul>
     <li> <a phx-click="toggle_modal" phx-value-command={to_string(command)} > <%= to_string(command) %> </a> </li>
     </ul>
     <% end %>
     <h3> Read Models </h3>


    	</div>
    	</div>
    	"""
  end



end
