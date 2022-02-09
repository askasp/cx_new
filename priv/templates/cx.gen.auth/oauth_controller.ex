
defmodule <%= inspect context.web_module %>.Auth.UserOauthController do
  use <%= inspect context.web_module %>, :controller
  alias <%= inspect context.base_module %>.ReadModel.AuthUser
  alias <%= inspect context.web_module %>.Auth.UserAuth
  plug Ueberauth
  def callback(%{assigns: %{ueberauth_auth: %{info: user_info}}} = conn, %{"provider" => "google"}) do
    IO.puts "user auth is"
    email_is_available = length(AuthUser.get_by_email(user_info.email)) == 0
    %<%=inspect context.base_module %>.Command.AddUser{email: user_info.email, stream_id: user_info.email , email_is_available: to_string(email_is_available)}
    |> <%= inspect context.base_module %>.CommandDispatcher.dispatch()
    |> case do
      :ok -> UserAuth.log_in_user(conn, %{id: user_info.email, email: user_info.email})
      {:error, :already_exists} -> UserAuth.log_in_user(conn, AuthUser.get(user_info.email))
      _ -> conn
        |> put_flash(:error, "Authentication failed")
        |> redirect(to: "/")
    end
  end

  def callback(conn, _params) do
    conn
    |> put_flash(:error, "Authentication failed")
    |> redirect(to: "/")
  end
end
