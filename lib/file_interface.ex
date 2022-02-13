defmodule CxNew.FileInterface do
  alias CxNew.Helpers

  def recompile() do
    IEx.Helpers.recompile()
  end

  def get_flows() do
    case File.ls("lib/cx_scaffold/flows") do
      {:error, _} ->
        []

      {:ok, files} ->
        Enum.map(files, fn file ->
          filename = String.split(file, ".e") |> Enum.at(0)
          String.to_existing_atom("Elixir.#{Helpers.app()}.Flow.#{Macro.camelize(filename)}")
        end)
    end
  end

  def write_flow(flow_name, flow) do
    File.mkdir_p("lib/cx_scaffold/flows")

    File.write(
      "lib/cx_scaffold/flows/#{flow_name}.ex",
      """
      defmodule #{Helpers.app()}.Flow.#{Macro.camelize(flow_name)} do
      def flow do
        #{inspect(flow)}
       end
      end
      """
    )
  end

  def write_read_model_supervisor(read_model) do
    {:ok, list} = :application.get_key(CxNew.Helpers.erlang_app(), :modules)

    read_models =
      list
      |> Enum.filter(&(&1 |> Module.split() |> Enum.take(2) == [CxNew.Helpers.app(), "ReadModel"]))

    read_model_module =
      case String.contains?("#{read_model}", "Elixir") do
        false -> "Elixir.#{read_model}" |> String.to_existing_atom()
        true -> "#{read_model}" |> String.to_existing_atom()
      end

    read_models = (read_models ++ [read_model_module]) |> Enum.uniq()

    IO.inspect(read_models)

    File.write(
      "lib/cx_scaffold/read_model_supervisor.ex",
      """
      defmodule #{Helpers.app()}.ReadModelSupervisor do
      use Supervisor
        def start_link(init_arg) do
          Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
        end

        @impl true
        def init(_init_arg) do
          children = #{inspect(read_models)}
          Supervisor.init(children, strategy: :one_for_one)
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
    Helpers.string_to_existing_module("Flow", flowname)
  end

  def add_liveview_to_flow(flow, liveview_name, dispatched_by \\ nil) do
    case File.read("lib/cx_scaffold/liveviews/#{liveview_name}_live.ex") do
      {:error, _} ->
        File.mkdir_p("lib/cx_scaffold/liveviews")

        File.write("lib/cx_scaffold/liveviews/#{liveview_name}_live.ex", """
        defmodule #{Helpers.app()}Web.#{Macro.camelize(liveview_name)}Live do

        use #{Helpers.web_module()}, :live_view
          def mount(_, session, socket) do
        		user = Map.get(session, "current_user_id")
        		|> case do
          		nil -> nil
        		  id  -> Genauthest.ReadModel.AuthUser.get(id)
        		end
            {:ok, assign(socket, current_user: user)}
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
            "module" => String.to_existing_atom("Elixir.#{Helpers.app()}Web.#{Macro.camelize(liveview_name)}Live"),
            "dispatched_by" => dispatched_by
          }
        ]

    write_flow(Helpers.flow_name_from_flow(flow), new_flow)
  end

  def create_command_dispatcher() do
    case File.read("lib/cx_scaffold/command_dispatcher.ex") do
      {:ok, _} ->
        :ok

      __ ->
        File.write("lib/cx_scaffold/command_dispatcher.ex", """
            defprotocol #{Helpers.app()}.CommandDispatcher do
        	def dispatch(command)
        end
        """)

        :ok
    end

    recompile()
  end

  def add_read_model_to_flow(flow, rm_name, dispatched_by \\ nil) do
    handler =
      case dispatched_by do
        nil ->
          ""

        gui_id ->
          [component] = Enum.filter(flow.flow(), fn component -> component["gui_id"] == gui_id end)

          """

          def handle_event({%#{Helpers.strip_elixir_from_module(component["module"])}{stream_id: stream_id} = event, metadata}) do
           # get state
           # |> update state
           # |>persist state
           :ok
          end

          """
      end

    case File.read("lib/cx_scaffold/read_models/#{rm_name}.ex") do
      {:ok, content} ->
        lines = String.split(content, "\n", trim: true)
        new_lines = List.insert_at(lines, -2, handler)
        File.write("lib/cx_scaffold/read_models/#{rm_name}.ex", Enum.join(new_lines, "\n"))

      {:error, _} ->
        File.mkdir_p("lib/cx_scaffold/read_models")

        File.write("lib/cx_scaffold/read_models/#{rm_name}.ex", """
        defmodule #{Helpers.app()}.ReadModel.#{Macro.camelize(rm_name)} do
          use ReadModel
          #{handler}



          def handle_event({_, metadata}), do: update_bookmark(metadata)
        end
        """)
    end

    # # add to read_model_supervisor
    # case File.read("lib/cx_scaffold/read_model_supervisor.ex") do
    #   {:ok, content} ->

    recompile()
    current_flows = flow.flow()
    guid = UUID.uuid1()

    new_flow =
      current_flows ++
        [
          %{
            "gui_id" => guid,
            "type" => "read_model",
            "module" => String.to_existing_atom("Elixir.#{Helpers.app()}.ReadModel.#{Macro.camelize(rm_name)}"),
            "dispatched_by" => dispatched_by
          }
        ]

    write_flow(Helpers.flow_name_from_flow(flow), new_flow)
    recompile()
    write_read_model_supervisor("#{Helpers.app()}.ReadModel.#{Macro.camelize(rm_name)}")
  end

  def add_processer_to_flow(flow, processer_name, dispatched_by \\ nil) do
    case File.read("lib/cx_scaffold/processers/#{processer_name}.ex") do
      {:ok, _} ->
        :error

      {:error, _} ->
        File.mkdir_p("lib/cx_scaffold/processers")

        File.write("lib/cx_scaffold/processers/#{processer_name}.ex", """
        defmodule #{Helpers.app()}.Processer.#{Macro.camelize(processer_name)} do
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
            "module" => String.to_existing_atom("Elixir.#{Helpers.app()}.Processer.#{Macro.camelize(processer_name)}"),
            "dispatched_by" => dispatched_by
          }
        ]

    write_flow(Helpers.flow_name_from_flow(flow), new_flow)
  end



  def add_command_to_flow(flow, command_name, event_name, shared_params, aggregate, dispatched_by \\ nil) do
    create_command_dispatcher()
    shared_params = [:stream_id | shared_params]

		# Used if aggregate already exixsts
    agg_function = """
    	def execute(%Command.#{Macro.camelize(command_name)}{}, state) do
      	{:ok, %Event.#{Macro.camelize(event_name)}{}}
    	end

    	def apply_event(state,%Event.#{Macro.camelize(event_name)}{}) do
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
        defmodule #{Helpers.app()}.Command.#{Macro.camelize(command_name)} do
          defstruct #{inspect(shared_params)}
        end

        defimpl #{Helpers.app()}.CommandDispatcher, for: #{Helpers.app()}.Command.#{Macro.camelize(command_name)} do
          def dispatch(command) do
            #{Helpers.app()}.Aggregate.#{Macro.camelize(aggregate)}.execute(command)
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
            defmodule #{Helpers.app()}.Aggregate.#{Macro.camelize(aggregate)} do
              use Aggregate
              alias #{Helpers.app()}.Command
              alias #{Helpers.app()}.Event
              def execute(%Command.#{Macro.camelize(command_name)}{} = cmd, state) do
              	{:ok, %Event.#{Macro.camelize(event_name)}{}}
              end

            	def apply_event(state,%Event.#{Macro.camelize(event_name)}{}) do
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
        defmodule #{Helpers.app()}.Event.#{Macro.camelize(event_name)} do
          @derive Jason.Encoder
          defstruct #{inspect(shared_params)}
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
            "module" => String.to_existing_atom("Elixir.#{Helpers.app()}.Command.#{Macro.camelize(command_name)}"),
            "dispatched_by" => dispatched_by
          },
          %{
            "gui_id" => UUID.uuid1(),
            "type" => "event",
            "module" => String.to_existing_atom("Elixir.#{Helpers.app()}.Event.#{Macro.camelize(event_name)}"),
            "dispatched_by" => command_gui_id,
            "aggregate" => String.to_existing_atom("Elixir.#{Helpers.app()}.Aggregate.#{Macro.camelize(aggregate)}")
          }
        ]
    write_flow(Helpers.flow_name_from_flow(flow), new_flow)
    recompile()
  end



end

defmodule CxNew.Helpers do
  defp strip_command_event(module) do
    string_list = String.split(module, ".", parts: 2)

    Enum.member?(["Aggregate", "Command", "Event", "ReadModel", "EventHandler", "Flow", "Processer"], Enum.at(string_list, 0))
    |> case do
      true -> Enum.at(string_list, 1)
      false -> module
    end
  end

  def flow_name_from_flow(flow) do
    module_to_string(flow) |> String.downcase()
  end

  def strip_elixir_from_module(module), do: String.split(to_string(module), "Elixir.") |> Enum.at(1)
  def strip_app_from_module(module), do:
  		String.split(to_string(module), "#{app()}.")
  		|> Enum.at(1)

  def module_to_string(module),
    do:
    strip_elixir_from_module(module)
    |> strip_app_from_module()
    |> strip_command_event()
    |> Macro.underscore()

  def string_to_existing_module(type, string),
    do: String.to_existing_atom("Elixir.#{app()}.#{type}.#{Macro.camelize(string)}")

  def none_to_nil("None"), do: nil
  def none_to_nil(x), do: x

  def app(), do: Application.get_env(:cx_new, :app) |> strip_elixir_from_module()
  def erlang_app(), do: Application.get_env(:cx_new, :erlang_app)


  def map_spear_event_to_domain_event(%Spear.Event{body: body, type: type, metadata: md} = spear_event) do
    try do
      ## this will give duplicated
      nil = spear_event.link
      body = Jason.decode!(body, keys: :atoms)
      IO.puts("event type is")
      IO.inspect(Macro.camelize(type))

      {("Elixir.#{CxNew.Helpers.app()}.Event." <> Macro.camelize(type))
       |> String.to_existing_atom()
       |> struct(body), md}
    rescue
      e -> {%{}, md}
    end
  end

  def map_spear_event_to_domain_event(_event), do: {%{}, %{}}

  def web_module do
    base = Mix.Phoenix.base()

    cond do
      Mix.Phoenix.context_app() != Mix.Phoenix.otp_app() ->
        Module.concat([base])

      String.ends_with?(base, "Web") ->
        Module.concat([base])

      true ->
        Module.concat(["#{base}Web"])
    end
  end
end
