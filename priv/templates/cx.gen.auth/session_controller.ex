defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>SessionController do
  use <%= inspect context.web_module %>, :controller

  alias <%= inspect context.module %>
  alias <%= inspect auth_module %>

  def new(conn, _params) do
    render(conn, "new.html", error_message: nil)
  end


  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> <%= inspect schema.alias %>Auth.log_out_user()
  end
end
