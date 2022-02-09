defmodule <%= inspect context.base_module %>.Flow.AddUserFlow do

  def flow() do[
          %{
            "gui_id" => "1",
            "type" => "command",
            "module" => <%= inspect context.base_module %>.Command.AddUser,
            "dispatched_by" => nil
          },
          %{
            "gui_id" => "2",
            "type" => "event",
            "module" => <%= inspect context.base_module %>.Command.UserAdded,
            "dispatched_by" => "1",
            "aggregate" => <%= inspect context.base_module %>.Aggregate.UserAggregate
          },
          %{
            "gui_id" => UUID.uuid1(),
            "type" => "read_model",
            "module" => <%= inspect context.base_module %>.ReadModel.AuthUser,
            "dispatched_by" => "2",
          }
          ]
  end
  end
