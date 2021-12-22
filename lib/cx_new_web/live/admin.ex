defmodule CxNewWeb.AdminLive do
  use CxNewWeb, :live_view


  def mount(_params, _, socket) do
    IEx.Helpers.recompile()

    streams = get_streams()

    {:ok, list} = :application.get_key(:cx_new, :modules)
    commands =
      list
      |> Enum.filter(&(&1 |> Module.split() |> Enum.take(1) == ~w|Command|))

    read_models =
      list
      |> Enum.filter(&(&1 |> Module.split() |> Enum.take(1) == ~w|ReadModel|))
      |> tail

    {:ok,
     assign(socket, command: nil, streams: streams, checked: nil, events: [], commands: commands, modal_open: false, read_models: read_models, read_model: nil, read_model_data: nil)}
  end


  def handle_event("show_rm_data", %{"rm_id" => id, "read_model" => read_model}, socket) do
    read_model= String.to_existing_atom("Elixir.ReadModel.#{String.capitalize(read_model)}")
    data = read_model.get(id)
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

  def handle_event("dispatch", params, socket) do
    atom_params =
      for {key, val} <- params, into: %{} do
        cond do
          is_atom(key) -> {key, val}
          true -> {String.to_atom(key), val}
        end
      end

    struct = struct(socket.assigns.command, atom_params)
    CommandDispatcher.dispatch(struct)
    streams = get_streams()

    {:noreply, assign(socket, modal_open: false, streams: streams)}
  end

  def handle_event("toggle_command_modal", %{}, socket) do
    {:noreply, assign(socket, modal_open: false)}
  end

  def render(assigns) do
    ~H"""
    <div class="p-20 pt-5">
    	<div class="prose " style="max-width:none;">
       <h1 class=""> Admin Panel</h1>
    	 	<div class="py-5" >
   				<h3 class=""> Dispatch a Command</h3>
    			<%= if @command do %>
    				<input type="checkbox" checked={@modal_open} class="modal-toggle" >
            <div class="modal">
              <div class="modal-box">
              <h3> <%= to_string(@command) %> </h3>

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
                 <input type="submit" class="btn btn-primary" value="Dispatch" >
                 <label for="my-modal-2" class="btn" phx-click="toggle_command_modal" >Close</label>
                </div>
              </form>
            </div>
            </div>
          <% end %>

    		<div class="grid grid-cols-4 gap-4">
          <%= for command <- @commands do %>
            <ul>
              <button class="btn btn-md btn-primary" phx-click="toggle_command_modal" phx-value-command={to_string(command)} > <%= to_string(command) %> </button>
            </ul>
          <% end %>
        </div>

      <h3> Read Models </h3>
  		<div class="grid grid-cols-4 gap-4">
      	<%= for read_model <- @read_models do %>
        	<div class=" w-full pb-2 border rounded-box border-base-300 collapse-arrow">
            <div class=" text-left collapse-title text-xl font-medium">
      				<%= CxNewWeb.CanvasLive.module_to_string(read_model) %>
            </div>
            <form phx-submit="show_rm_data">
    					<div class="form-control">
          			<div class="flex space-x-2 px-4">
            			<input requierd type="text" name="rm_id" placeholder="Read model id" class="w-1/2 input input-primary input-bordered">
            			<input hidden name="read_model" value={CxNewWeb.CanvasLive.module_to_string(read_model)} />
            			<button class="btn btn-primary">show </button>
          			</div>
        			</div>
        		</form>
        		<%= if read_model == @read_model  && @read_model_data do %>
          		<div class="px-4">
            		<h4> State </h4>
          			<%= for {key, value} <- @read_model_data do %>
            			<span> <b> <%= key %>: </b> <%= value %> </span>
            	  <% end %>
          		</div>
          	<% end %>
          </div>
        <% end %>
      </div>


    <h3> Streams </h3>
    <div class="overflow-x-auto">
      <table class="table w-full table-compact">
        <thead>
          <tr>
            <th></th> 
            <th>id </th>
            <th>Aggregate</th>
            <th> Events</th>
          </tr>
        </thead> 
        <tbody>
        <%= for {stream, index} <- Enum.with_index(@streams) do %>
          <tr class="">
            <th><%= index %> </th>
            <td><%= stream["stream_id"] %> </td>
            <td><%= stream["aggregate"] %> </td>
            <td> <ol>
            <%= for event <- stream["events"] do %>
            	<li> <%= event.type %> </li>
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


  defp get_streams() do
      Spear.stream!(CxNew.EventStoreDbClient, "$streams")
      |> Enum.to_list()
      |> Enum.map(fn x ->
    		{:ok, events} = Spear.read_stream(CxNew.EventStoreDbClient, x.metadata.stream_name, max_count: 50)
        %{"stream_id" => get_stream_id(x.metadata.stream_name),
        	"aggregate" => get_stream_aggregate(x.metadata.stream_name),
        	"events" => events}
        end)
   end

end
