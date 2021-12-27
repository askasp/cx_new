defmodule CxNewWeb.AdminLive do
  use CxNewWeb, :live_view
  require Logger

  def mount(_params, _, socket) do
    IEx.Helpers.recompile()

    streams = get_streams()


    IO.inspect streams
    events = Enum.map(streams, fn stream -> stream["events"]|> Enum.map(fn event -> IO.inspect event end) end)
    IO.inspect events

		{:ok, list}  = :application.get_key(CxNew.Helpers.erlang_app(), :modules)

    commands =
      list
      |> Enum.filter(&(&1 |> Module.split() |> Enum.take(2) == [CxNew.Helpers.app(), "Command"]))



    read_models =
      list
      |> Enum.filter(&(&1 |> Module.split() |> Enum.take(2) == [CxNew.Helpers.app(), "ReadModel"]))

    {:ok,
     assign(socket, command: nil, streams: streams, checked: nil, events: [], commands: commands, modal_open: false, read_models: read_models, read_model: nil, read_model_data: nil, event: nil,  event_metadata: nil, alert_content: nil)}
  end


  def handle_event("show_rm_data", %{"rm_id" => id, "read_model" => read_model}, socket) do
    read_model  = CxNew.Helpers.string_to_existing_module("ReadModel",read_model)
    data = read_model.get(id)
    IO.puts "got data"
    IO.inspect data
    case socket.assigns.read_model do
      x when x == read_model ->
        {:noreply, assign(socket, read_model: nil)}
      _ ->
        {:noreply, assign(socket, read_model: read_model, read_model_data: data)}
    end
  end

  def handle_event("toggle_command_modal", %{"command" => string_command}, socket) do
    {:noreply, assign(socket, modal_open: true, command: String.to_existing_atom(string_command))}
  end



  def handle_event("load_events", %{"stream" => clicked_stream}, socket ) do
    [chosen_stream] = socket.assigns.streams |> Enum.filter(fn stream -> stream["stream_id"] == clicked_stream end)
    IO.inspect chosen_stream

    {:ok, events} = Spear.read_stream(CxNew.EventStoreDbClient, chosen_stream["aggregate"]<> ":" <>chosen_stream["stream_id"], max_count: 99999)
    IO.puts "events are"
    events = Enum.map(events, fn event -> CxNew.Helpers.map_spear_event_to_domain_event(event) end)
    IO.inspect events
    new_stream = Map.put(chosen_stream, "events", events)
    new_streams = socket.assigns.streams |> Enum.map(fn stream ->
      if stream["stream_id"] == clicked_stream do
        new_stream
      else
      	stream
      end
      end)

    {:noreply, assign(socket, streams: new_streams)}
  end


  def handle_event("set_event", %{"stream" => clicked_stream, "revision" => revision}, socket ) do
    [chosen_stream] = socket.assigns.streams |> Enum.filter(fn stream -> stream["stream_id"] == clicked_stream end)
    {event, metadata} = Enum.at(chosen_stream["events"], String.to_integer(revision))
    {:noreply, assign(socket, event: event, event_metadata: metadata)}
  end

  def handle_event("nil_event", _, socket ) do
    {:noreply, assign(socket, event: nil, event_metadata: nil)}
  end


  def handle_event("dispatch", params, socket) do
    atom_params =
      for {key, val} <- params, into: %{} do
        cond do
          is_atom(key) -> {key, val}
          true -> {String.to_atom(key), val}
        end
      end

    struct = struct(socket.assigns.command, atom_params)
    case CommandDispatcher.dispatch(struct) do
      :ok -> streams = get_streams()
      			{:noreply, assign(socket, modal_open: false, streams: streams)}
      {:error, err} when is_binary(err) ->
        		 Logger.error("Something went wrong #{inspect(err)}") ## Create an alert modal here
      			 {:noreply, assign(socket, alert_content: err)}

      err when is_binary(err) ->
        		 Logger.error("Something went wrong #{inspect(err)}") ## Create an alert modal here
      			 {:noreply, assign(socket, alert_content: err)}

      err ->
        		 Logger.error("Something went wrong #{inspect(err)}") ## Create an alert modal here
      			 {:noreply, assign(socket, alert_content: "Something went wrong")}
      	end
  end

  def handle_event("toggle_command_modal", %{}, socket) do
    {:noreply, assign(socket, modal_open: false)}
  end

  def render(assigns) do
    ~H"""

  	<link href="https://cdn.jsdelivr.net/npm/tailwindcss@2.2/dist/tailwind.min.css" rel="stylesheet" type="text/css" />
 		<link href="https://cdn.jsdelivr.net/npm/daisyui@1.19.0/dist/full.css" rel="stylesheet" type="text/css" />



    <%= if @alert_content do %>
    <div class="alert alert-error">
      <div class="flex-1">
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="w-6 h-6 mx-2 stroke-current">    
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636"></path>                      
        </svg> 
        <label><%= @alert_content %></label>
      </div>
    </div>

    <% end %>



 		<%= view_event(%{event: @event, event_metadata: @event_metadata}) %>

    <div class="p-20 pt-5">
    	<div class="" style="max-width:none;">
       <h1 class="text-3xl font-bold"> Admin Panel</h1>
    	 	<div class="py-5" >
   				<h3 class="text-xl mt-8 mb-1 font-bold"> Dispatch a Command</h3>
    			<%= if @command do %>
    				<input type="checkbox" checked={@modal_open} class="modal-toggle" >
            <div class="modal">
                <%= if @alert_content do %>
                <div class="alert alert-error">
                  <div class="flex-1">
                    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="w-6 h-6 mx-2 stroke-current">    
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636"></path>                      
                    </svg> 
                    <label><%= @alert_content %></label>
                  </div>
                </div>
                <% end %>
              <div class="modal-box">
              <h3 class="text-lg font-bold mb-2"> <%= CxNew.Helpers.module_to_string(@command) %> </h3>
              <form phx-submit="dispatch" >
                <div class="form-control">
                  <%= for key <- Map.keys(Map.from_struct(@command)) do %>
                    <label class="label">
                      <span class="label-text"> <%= key %> </span>
                    </label> 
                    <input type="text" name={key}  class="input input-bordered">
                  <% end %>
                </div>

                <div class="modal-action">
                 <button type="submit" class="btn btn-primary"> Dispatch </button>
                 <button for="my-modal-2" class="btn" phx-click="toggle_command_modal" >Close</button>
                </div>
              </form>
            </div>
            </div>
          <% end %>

    		<div class="grid grid-cols-4 gap-4">
          <%= for command <- @commands do %>
            <ul>
              <button class="btn btn-md btn-primary" phx-click="toggle_command_modal" phx-value-command={to_string(command)} > <%= CxNew.Helpers.module_to_string(command) %> </button>
            </ul>
          <% end %>
        </div>

   		<h3 class="text-xl mt-8 mb-1 font-bold"> Read Models </h3>
  		<div class="grid grid-cols-4 gap-4">
      	<%= for read_model <- @read_models do %>
        	<div class=" w-full pb-2 border rounded-box border-base-300 collapse-arrow">
            <div class=" text-left collapse-title text-xl font-medium">
      				<%= CxNew.Helpers.module_to_string(read_model) %>
            </div>
            <form phx-submit="show_rm_data">
    					<div class="form-control">
          			<div class="flex space-x-2 px-4">
            			<input requierd type="text" name="rm_id" placeholder="Read model id" class="w-1/2 input input-primary input-bordered">
            			<input hidden name="read_model" value={CxNew.Helpers.module_to_string(read_model)} />
            			<button class="btn btn-primary">show </button>
          			</div>
        			</div>
        		</form>
        		<%= if read_model == @read_model  && @read_model_data do %>
          		<div class="px-4">
            		<h4 class="text-lg font-bold"> State </h4>
            		<%= if is_map(@read_model_data) do %>
          				<%= for {key, value} <- @read_model_data do %>
            				<span class=" text-sm"> <b class="font-bold text-sm"> <%= key %>: </b> <%= value %> </span>
            	  	<% end %>
            	  <% else %>
            			<span class=" text-sm"> <b class="font-bold text-sm"> value: </b> <%= @read_model_data %> </span>
            	  <% end %>
          		</div>
          	<% end %>
          </div>
        <% end %>
      </div>

   <h3 class="text-xl mt-8 mb-1 font-bold"> Streams </h3>
    <div class="overflow-x-auto">
      <table class="table w-full table-compact">
        <thead>
          <tr>
            <th>id </th>
            <th>Aggregate</th>
            <th> Events</th>
          </tr>
        </thead> 
        <tbody>
        <%= for {stream, index} <- Enum.with_index(@streams) do %>
          <tr class="">
            <td><%= stream["stream_id"] %> </td>
            <td><%= stream["aggregate"] %> </td>
            <td> <ol>
            <%= if length(stream["events"]) > 0 do %>
            <%= for {event, metadata} <- stream["events"] do %>
            	<li>
            		<a  phx-click="set_event" phx-value-stream={stream["stream_id"]} phx-value-revision={metadata.stream_revision}> <%= event.__struct__ |> Module.split |> Enum.join(".") %> </a>
              </li>
            <% end %>
            <%= else %>
            		<a  phx-click="load_events" phx-value-stream={stream["stream_id"]} > Load events </a>
            <% end %>
            </ol>
            </td>
          </tr>
          <% end %>
        </tbody>
      </table>
    </div>
  </div>
</div>
</div>
    """
  end
  defp tail([_ | tail]), do: tail
  defp get_stream_id(stream_name) do
    String.split(stream_name, ":") |> Enum.at(-1)
  end

  defp get_stream_aggregate(stream_name) do
    String.split(stream_name, ".") |> Enum.at(-1) |> String.split(":") |> Enum.at(0)
  end

  def view_event(assigns) do
    ~H"""
    <%= if @event do %>
    				<input type="checkbox" checked={@event != nil} class="modal-toggle" >
            <div class="modal">
              <div class="modal-box">
              <h3 class="text-lg font-bold mb-2"> <%= @event.__struct__ |> Module.split |> Enum.join(".") %> </h3>
              <div>
                  <%= for {key,value} <- (Map.from_struct(@event)) do %>
                    <label class="label">
                      <span class="label-text"> <%= key %>: <%= value %>  </span>
                    </label>
                    <% end %>
               </div>

                <div class="modal-action">
                 <button for="my-modal-2" class="btn" phx-click="nil_event" >Close</button>

                </div>
            </div>
            </div>
            <% end %>
           """
  end

  defp get_streams() do
      Spear.stream!(CxNew.EventStoreDbClient, "$streams")
      |> Enum.to_list()
      |> Enum.map(fn x ->
        IO.inspect x.metadata.stream_name
        %{"stream_id" => get_stream_id(x.metadata.stream_name),
        	"aggregate" => get_stream_aggregate(x.metadata.stream_name),
        	"events" =>  []}
        end)
   end

end
