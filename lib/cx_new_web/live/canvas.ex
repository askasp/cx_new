defmodule CxNewWeb.CanvasLive do
  @height_unit 100
  @width_unit 100
  # If you generated an app with mix phx.new --live,
  # the line below would be: use MyAppWeb, :live_view
  use CxNewWeb, :live_view

  def mount(_params, %{}, socket) do
    {:ok,
     assign(socket,
       myheight: @height_unit,
       flow: nil,
       flow_name_suggestion: "myflow",
       show_add_flow_modal: false,
       flows: get_flows()
     )}
  end

  def handle_params(%{"flow" => flow_filename}, _uri, socket) do
    IO.inspect(flow_filename)
    flow_module = String.to_existing_atom("Elixir.Flow.#{String.capitalize(flow_filename)}")
    IO.inspect(flow_module)
    {:noreply, assign(socket, flow: flow_module)}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  def handle_event("set_flow", %{"flow" => flow}, socket) do
    IO.inspect(flow)
    {:noreply, push_patch(socket, to: Routes.canvas_path(socket, :show, String.downcase(flow)))}
  end

  def handle_event("toggle_add_flow_modal", %{}, socket) do
    {:noreply, assign(socket, show_add_flow_modal: !socket.assigns.show_add_flow_modal)}
  end

  def handle_event("validate_flow_name", %{"filename" => filename}, socket) do
    {:noreply, assign(socket, flow_name_suggestion: filename)}
  end

  def handle_event("create_flow", %{"filename" => filename}, socket) do
    new_flow = create_flow(filename)
    {:noreply, assign(socket, flows: get_flows(), show_add_flow_modal: false)}
  end

  @impl true
  def handle_event("add_liveview", %{"filename" => filename, "dispatched_by" => dispatched_by}, socket) do
    case dispatched_by do
      "None" -> add_liveview_to_flow(socket.assigns.flow, filename, nil)
      _ -> add_liveview_to_flow(socket.assigns.flow, filename, dispatched_by)
    end

    {:noreply,
     redirect(socket, to: Routes.canvas_path(socket, :show, String.downcase(module_to_string(socket.assigns.flow))))}
  end

  @impl true
  def handle_event(
        "add_command_and_event",
        %{
          "command_filename" => command_filename,
          "event_filename" => event_filename,
          "aggregate_filename" => aggregate_filename,
          "stream_id" => stream_id,
          "dispatched_by" => dispatched_by
        },
        socket
      ) do
    case dispatched_by do
      "None" ->
        add_command_to_flow(socket.assigns.flow, command_filename, stream_id, event_filename, aggregate_filename, nil)

      _ ->
        add_command_to_flow(
          socket.assigns.flow,
          command_filename,
          stream_id,
          event_filename,
          aggregate_filename,
          dispatched_by
        )
    end

    {:noreply,
     redirect(socket, to: Routes.canvas_path(socket, :show, String.downcase(module_to_string(socket.assigns.flow))))}
  end

  @impl true
  def handle_event(
        "add_read_model",
        %{
          "rm_filename" => rm_filename,
          "dispatched_by" => dispatched_by
        },
        socket
      ) do
    case dispatched_by do
      "None" ->
        add_read_model_to_flow(socket.assigns.flow, rm_filename, nil)

      _ ->
        add_read_model_to_flow(socket.assigns.flow, rm_filename, dispatched_by)
    end

    {:noreply,
     redirect(socket, to: Routes.canvas_path(socket, :show, String.downcase(module_to_string(socket.assigns.flow))))}
  end


  @impl true
  def handle_event(
        "add_processer",
        %{
          "processer_filename" => processer_filename,
          "dispatched_by" => dispatched_by
        },
        socket
      ) do
    case dispatched_by do
      "None" ->
        add_processer_to_flow(socket.assigns.flow, processer_filename, nil)

      _ ->
        add_processer_to_flow(socket.assigns.flow, processer_filename, dispatched_by)
    end

    {:noreply,
     redirect(socket, to: Routes.canvas_path(socket, :show, String.downcase(module_to_string(socket.assigns.flow))))}
  end


  def module_to_string(module), do: String.split(to_string(module), "Elixir.") |> Enum.at(1) |> strip_command_event()

  defp strip_command_event(module) do
    string_list = String.split(module, ".", parts: 2)

    Enum.member?(["Command", "Event", "ReadModel", "EventHandler", "Flow"], Enum.at(string_list, 0))
    |> case do
      true -> Enum.at(string_list, 1)
      false -> module
    end
  end

  def get_flows() do
    case File.ls("lib/cx_scaffold/flows") do
      {:error, _} ->
        []

      {:ok, files} ->
        Enum.map(files, fn file ->
          filename = String.split(file, ".e") |> Enum.at(0)
          String.to_existing_atom("Elixir.Flow.#{String.capitalize(filename)}")
        end)
    end
  end

  def get_aggregates(flow) do
    flow.flow()
    |> Enum.filter(fn x -> x["type"] == "event" end)
    |> Enum.map(fn event -> event["aggregate"] end)
    |> Enum.uniq()
  end

  defp aggregate_height(i), do: (6 + 1.5 * i) * @height_unit

  defp event_height(event_component, aggregates) do
    IO.inspect(event_component)
    IO.inspect(aggregates)

    Enum.find_index(aggregates, fn x -> x == event_component["aggregate"] end)
    |> aggregate_height
  end

  defp left_shift(_component, i), do: (4 + i) * @width_unit


  def recompile() do
    IEx.Helpers.recompile()
  end

  def write_flow(flow_name, flow) do
    File.mkdir_p("lib/cx_scaffold/flows")

    File.write(
      "lib/cx_scaffold/flows/#{flow_name}.ex",
      """
      defmodule Flow.#{String.capitalize(flow_name)} do
      def flow do
        #{inspect(flow)}
       end
      end
      """
    )
  end

  def create_flow(flowname) do
    case File.read("lib/cx_scaffold/flows/flowname.ex") do
      {:ok, _} ->
        {:error, "flow exists"}

      _ ->
        write_flow(flowname, [])
    end

    recompile()
    String.to_existing_atom("Elixir.Flow.#{String.capitalize(flowname)}")
  end

  defp flow_name_from_flow(flow) do
    module_to_string(flow) |> String.downcase()
  end

  def add_liveview_to_flow(flow, liveview_name, dispatched_by \\ nil) do
    case File.read("lib/cx_scaffold/liveviews/#{liveview_name}.ex") do
      {:error, _} ->
        File.mkdir_p("lib/cx_scaffold/liveviews")

        File.write("lib/cx_scaffold/liveviews/#{liveview_name}.ex", """
        defmodule LiveView.#{String.capitalize(liveview_name)} do
        use Phoenix.LiveView
          def mount(_params, %{}, socket) do
            {:ok, socket}
          end

          def render(assigns) do
          end
        end

        """)

      _ ->
        :ok
    end

    current_flows = flow.flow()
    recompile()

    new_flow =
      current_flows ++
        [
          %{
            "gui_id" => UUID.uuid1(),
            "type" => "liveview",
            "module" => String.to_existing_atom("Elixir.LiveView.#{String.capitalize(liveview_name)}"),
            "dispatched_by" => dispatched_by
          }
        ]

    write_flow(flow_name_from_flow(flow), new_flow)
  end

  def create_command_dispatcher() do
    case File.read("lib/cx_scaffold/command_dispatcher.ex") do
      {:ok, _} ->
        :ok

      __ ->
        File.write("lib/cx_scaffold/command_dispatcher.ex", """
            defprotocol CommandDispatcher do
        	def dispatch(command)
        end
        """)

        :ok
    end

    recompile()
  end

  def add_read_model_to_flow(flow, rm_name, dispatched_by \\ nil) do
    case File.read("lib/cx_scaffold/read_models/#{rm_name}.ex") do
      {:ok, _} ->
        :error

      {:error, _} ->
        File.mkdir_p("lib/cx_scaffold/read_models")

        File.write("lib/cx_scaffold/read_models/#{rm_name}.ex", """
        defmodule ReadModel.#{String.capitalize(rm_name)} do
          use ReadModel
        end
        """)
    end

    recompile()
    current_flows = flow.flow()
    guid = UUID.uuid1()

    new_flow =
      current_flows ++
        [
          %{
            "gui_id" => guid,
            "type" => "read_model",
            "module" => String.to_existing_atom("Elixir.ReadModel.#{String.capitalize(rm_name)}"),
            "dispatched_by" => dispatched_by
          }
        ]

    write_flow(flow_name_from_flow(flow), new_flow)
  end

  def add_processer_to_flow(flow, processer_name, dispatched_by \\ nil) do
    case File.read("lib/cx_scaffold/processers/#{processer_name}.ex") do
      {:ok, _} ->
        :error

      {:error, _} ->
        File.mkdir_p("lib/cx_scaffold/processers")

        File.write("lib/cx_scaffold/processers/#{processer_name}.ex", """
        defmodule Processer.#{String.capitalize(processer_name)} do
          #use Processor
        end
        """)
    end

    recompile()
    current_flows = flow.flow()
    guid = "a" <> UUID.uuid1()

    new_flow =
      current_flows ++
        [
          %{
            "gui_id" => guid,
            "type" => "processer",
            "module" => String.to_existing_atom("Elixir.Processer.#{String.capitalize(processer_name)}"),
            "dispatched_by" => dispatched_by
          }
        ]

    write_flow(flow_name_from_flow(flow), new_flow)
  end


  def add_command_to_flow(flow, command_name, stream_identifier, event_name, aggregate, dispatched_by \\ nil) do
    create_command_dispatcher()

    agg_function = """
    	def execute(%Command.#{String.capitalize(command_name)}{}, state) do
      	{%Event.#{String.capitalize(event_name)}{}, state}
    	end

    	def apply_event(%Event.#{String.capitalize(event_name)}{}, state) do
      	new_state = state
      	new_state
    	end
    """

    case File.read("lib/cx_scaffold/commands/#{command_name}.ex") do
      {:ok, _} ->
        :error

      {:error, _} ->
        File.mkdir_p("lib/cx_scaffold/commands")

        File.write("lib/cx_scaffold/commands/#{command_name}.ex", """
        defmodule Command.#{String.capitalize(command_name)} do
          defstruct [:#{stream_identifier}]
        end

        defimpl CommandDispatcher, for: Command.#{String.capitalize(command_name)} do
          def dispatch(command) do
            Aggregate.#{String.capitalize(aggregate)}.dispatch(command, :#{stream_identifier})

          end
        end
        """)

        case File.read("lib/cx_scaffold/aggregates/#{aggregate}.ex") do
          {:ok, content} ->
            lines = String.split(content, "\n", trim: true)
            new_lines = List.insert_at(lines, -2, agg_function)
            File.write("lib/cx_scaffold/aggregates/#{aggregate}.ex", Enum.join(new_lines, "\n"))

          _ ->
            File.mkdir_p("lib/cx_scaffold/aggregates")

            File.write("lib/cx_scaffold/aggregates/#{aggregate}.ex", """
            defmodule Aggregate.#{String.capitalize(aggregate)} do
            def execute(%Command.#{String.capitalize(command_name)}{}, state) do
            	{%Event.#{String.capitalize(event_name)}{}, state}
            end

          	def apply_event(%Event.#{String.capitalize(event_name)}{}, state) do
            	new_state = state
            	new_state
          	end

              end
            """)
        end
    end

    case File.read("lib/cx_scaffold/events/#{event_name}.ex") do
      {:ok, _} ->
        :error

      {:error, _} ->
        File.mkdir_p("lib/cx_scaffold/events")

        File.write("lib/cx_scaffold/events/#{event_name}.ex", """
        defmodule Event.#{String.capitalize(event_name)} do
          defstruct [:#{stream_identifier}]
        end
        """)
    end

    recompile()
    command_gui_id = UUID.uuid1()
    current_flows = flow.flow()

    new_flow =
      current_flows ++
        [
          %{
            "gui_id" => command_gui_id,
            "type" => "command",
            "module" => String.to_existing_atom("Elixir.Command.#{String.capitalize(command_name)}"),
            "dispatched_by" => dispatched_by
          },
          %{
            "gui_id" => UUID.uuid1(),
            "type" => "event",
            "module" => String.to_existing_atom("Elixir.Event.#{String.capitalize(event_name)}"),
            "dispatched_by" => command_gui_id,
            "aggregate" => String.to_existing_atom("Elixir.Aggregate.#{String.capitalize(aggregate)}")
          }
        ]

    write_flow(flow_name_from_flow(flow), new_flow)
    recompile()
  end

  def render(assigns) do
    ~H"""
        <div class="prose md:p-8">
        <h1 class=""> Generate Flows </h1>
        </div>

    	<div class="py-40" >
    		<%= case @flow do %>
    			<%= nil -> %> <%= choose_flow_page(%{flows: @flows, flow_name_suggestion: @flow_name_suggestion, show_add_flow_modal: @show_add_flow_modal}) %>
    			<%= _ -> %> <%= flow_page(%{flow: @flow.flow(), aggregates: get_aggregates(@flow), myheight: 100}) %>
    		<% end %>

     <%= if @flow do %>
        <%= for component <- @flow.flow() do %>
        	<%= if component["dispatched_by"] != nil  do %>

          	<connection from={"#" <> component["dispatched_by"]} to={"#" <> component["gui_id"]}  fromY="0.5"  toY="0.5" tail="true" ></connection>
            <% end %>
          <% end %>
    		<% end %>
    	</div>
    """
  end

  def choose_flow_page(assigns) do
    ~H"""
        <div class="mx-auto text-center">
          <%= for flow <- @flows do %>
          <div class="my-10">
            <button phx-click="set_flow" phx-value-flow={module_to_string(flow)} class=
            "btn btn-info"><%= module_to_string(flow) %></button>
          </div><%end %>
          <div class="my-20">
            <button phx-click="toggle_add_flow_modal" class="btn btn-secondary modal-button" > Create New Flow </button>
            <%= if @show_add_flow_modal do %>
            <div class="modal modal-open">
              <div class="modal-box prose text-left">
                <h3>Add Flow</h3>
                <form phx-submit="create_flow" phx-change="validate_flow_name" >
                <h4> Generated module: <%= "Flow.#{String.capitalize(@flow_name_suggestion)}" %>  </h4>
                  <div class="form-control">
                    <label class="label"><span class=
                    "label-text">Filename</span></label> <input name=
                    "filename" type="text" placeholder="myflow" class=
                    "input input-bordered">
                  </div>
                  <div class="modal-action">
                    <input for="my-modal-3" type="submit" class=
                    "btn btn-primary" value="Create">
                    <button class="toggle_add_flow_modal" class="btn">Close</button>
                  </div>
                </form>
              </div>
            </div>
            <% end %>
          </div>
        </div>

    """
  end

  def flow_page(assigns) do
    ~H"""

    <%= add_component_modal(%{flow: @flow}, "Add Liveview", "add_liveview", fn x -> liveview_form_custom_conent(x) end ) %>
    <%= add_component_modal(%{flow: @flow}, "Add Command &  Event", "add_command_and_event", fn x -> command_and_event_form_custom_content(x) end, "btn-info" ) %>
    <%= add_component_modal(%{flow: @flow}, "Add Read model", "add_read_model", fn x -> read_model_custom_form_content(x) end, "btn-success" ) %>
    <%= add_component_modal(%{flow: @flow}, "Add Processer", "add_processer", fn x -> processer_custom_form_content(x) end, "btn-secondary" ) %>

    <div class="px-10 prose">
    <%= for {aggregate,i} <- Enum.with_index(@aggregates) do %>
    <div style={"position: absolute; top: #{aggregate_height(i)}px"} >
    <h3> <%= module_to_string(aggregate) %> </h3>
    <div class="divider w-screen"></div>
    </div>
    <% end %>
     <div>

    <%= for {component,i} <- Enum.with_index(@flow) do %>
    <%=  case component["type"] do %>

    <%= "liveview" -> %>
    	<div id={component["gui_id"]}  class="bg-gray-500" style={"width:200px; height:200px; position: absolute; top: #{(1)*@myheight}px; left: #{left_shift(component,i)}px"} >
    		<%= component["module"].render(%{}) %>

    	</div>
    <%= "command" -> %>
    <div class="btn btn-info" id={component["gui_id"]} style={"position: absolute; top: #{(4)*@myheight}px; left: #{left_shift(component,i)}px"} >
    <%= module_to_string(component["module"]) %>
    </div>

    <%= "event" -> %>
    <div class="btn btn-warning"  id={component["gui_id"]}   style={"position: absolute; top: #{event_height(component, @aggregates)}px; left: #{left_shift(component,i)}px"} >
    <%= module_to_string(component["module"]) %>
    </div>

    <%= "processer" -> %>
    <div class="" id={component["gui_id"]}    style={"position: absolute; top: #{(1)*@myheight}px; left: #{left_shift(component,i)}px"} >
    <img class="mx-auto" width="60px" src={Routes.static_path(CxNewWeb.Endpoint, "/images/gear.png")} />

    <%= module_to_string(component["module"]) %>
    </div>

    <%= "read_model" -> %>
    <div id={component["gui_id"]} class="btn btn-success" style={"position: absolute; top: #{(4)*@myheight}px; left: #{left_shift(component,i)}px"} >
    <%= module_to_string(component["module"]) %>
    </div>

    <%= _ -> %> <div class="btn btn-info" style={"position: absolute; top: #{(5)*@myheight}px; left: (i + 2)*@myheightpx"} > hei </div>
    <% end %>
    <% end %>

    </div>


    </div>
    """
  end


  def liveview_form_custom_conent(assigns) do
    ~H"""
                  <div class="form-control">
                    <label class="label"><span class=
                    "label-text">Filename</span></label> <input name="filename"
                    type="text" placeholder="a_view"  class=
                    "input input-bordered">
                  </div>
    """

  end
    
  def add_component_modal(assigns, title, submit, custom_content, button_style \\ "") do
    ~H"""
        <div class="px-10 pb-5 prose">
            <label for={title} class={"btn btn-outline modal-button " <> button_style } >  <%= title %> </label> <input type="checkbox" id={title} class=
            "modal-toggle">
            <div class="modal">
              <div class="modal-box">
                <h4><%= title %> </h4>
                <form phx-submit={submit} >
                  <%= custom_content.(%{}) %>
                  <%= dispatched_by_select(%{flow: @flow}) %>
                  <div class="modal-action">
                    <input for={title} type="submit" class=
                    "btn btn-primary" value="Create"> <label for={title}
                    class="btn">Close</label>
                  </div>
                </form>
              </div>
            </div>
            </div>
    """
  end

  def dispatched_by_select(assigns) do
    ~H"""
    <div class="form-control">
    <label class="label mt-5"><span class="label-text">Dispatched
    by</span></label> <select name="dispatched_by" class=
    "select select-bordered w-full max-w-xs">
      <option selected="selected">
        None
      </option><%= for component <- @flow do %>
      <option value={component["gui_id"]}>
        <%= component["module"] %>
      </option><%end %>
    </select>
    </div>
    """
  end

  def read_model_custom_form_content(assigns) do
    ~H"""
      <div class="form-control">
        <label class="label"><span class="label-text">
        Read Model filename </span></label> <input name="rm_filename"
        type="text" placeholder="payments" class=
        "input input-bordered">
        </div>

    """

    end

  def processer_custom_form_content(assigns) do
    ~H"""
      <div class="form-control">
        <label class="label"><span class="label-text">
        Processer filename </span></label> <input name="processer_filename"
        type="text" placeholder="payments" class=
        "input input-bordered">
        </div>

    """

    end




  def command_and_event_form_custom_content(assigns) do
    ~H"""
                  <div class="form-control">
                    <label class="label"><span class=
                    "label-text">Command filename</span></label> <input name="command_filename"
                    type="text" placeholder="pay" class=
                    "input input-bordered">


                    <label class="label"><span class=
                    "label-text">Event filename</span></label> <input name="event_filename"
                    type="text"  placeholder="paid" class=
                    "input input-bordered">

                    <label class="label"><span class=
                    "label-text"> aggregate filename </span></label> <input name="aggregate_filename"
                    type="text"  placeholder="paymentaggregate" class=
                    "input input-bordered">


                    <label class="label"><span class=
                    "label-text">Stream Id</span></label> <input name="stream_id"
                    type="text" value="None" placeholder="order" class=
                    "input input-bordered">

                  </div>

    """
  end
end

defmodule CxNewWeb.PaymentLive do
  # If you generated an app with mix phx.new --live,
  # the line below would be: use MyAppWeb, :live_view
  use CxNewWeb, :live_view

  def render(assigns) do
    ~H"""
    heid

    """
  end

  def mount(_params, %{}, socket) do
    {:ok, socket}
  end
end
