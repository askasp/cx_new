defmodule <%= inspect context.base_module %>.Flow.AddUserFlow do

  def flow() do[
          %{
            "gui_id" => "add_user",
            "type" => "command",
            "module" => <%= inspect context.base_module %>.Command.AddUser,
            "dispatched_by" => nil
          },
          %{
            "gui_id" => "user_added",
            "type" => "event",
            "module" => <%= inspect context.base_module %>.Command.UserAdded,
            "dispatched_by" => "add_user",
            "aggregate" => <%= inspect context.base_module %>.Aggregate.UserAggregate
          },
          %{
            "gui_id" => "auth_user",
            "type" => "read_model",
            "module" => <%= inspect context.base_module %>.ReadModel.AuthUser,
            "dispatched_by" => "user_added",
          }
          ]
  end
  end
