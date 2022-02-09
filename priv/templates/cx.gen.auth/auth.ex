defmodule <%= inspect auth_module %> do
  import Plug.Conn
  import Phoenix.Controller

  alias <%= inspect context.base_module %>.ReadModel.AuthUser
  alias <%= inspect context.web_module %>.Router.Helpers, as: Routes

  # Make the remember me cookie valid for 60 days.
  # If you want bump or reduce this value, also change
  # the token expiry itself in <%= inspect schema.alias %>Token.
  @max_age 60 * 60 * 24 * 60

  @doc """
  Logs the user in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renew_session
  function to customize this behaviour.

  It also sets a `:live_socket_id` key in the session,
  so LiveView sessions are identified and automatically
  disconnected on log out. The line can be safely removed
  if you are not using LiveView.
  """
  def log_in_user(conn, user, params \\ %{}) do
		token = Phoenix.Token.sign(<%= inspect context.web_module%>.Endpoint, "user_auth", user.id)
		# token = Phoenix.Token.sign(MyAppWeb.Endpoint, "user auth", user_id)
    user_return_to = get_session(conn, :user_return_to)
    conn
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, "user_sessions:#{Base.url_encode64(token)}")
    |> redirect(to: user_return_to || signed_in_path(conn))
  end


  @doc """
  Logs the user out.
  It clears all session data for safety. See renew_session.
  """
  def log_out_user(conn) do
    if live_socket_id = get_session(conn, :live_socket_id) do
      <%= inspect(endpoint_module) %>.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> clear_session()
    |> redirect(to: "/")
  end

  @doc """
  Authenticates the user by looking into the session
  and remember me token.
  """
  def fetch_current_user(conn, _opts) do
    user_token = get_session(conn, :user_token)
		Phoenix.Token.verify(<%= inspect context.web_module%>.Endpoint, "user_auth", user_token, max_age: 604800)
		|> case do
  		{:ok, id} ->
    		user = AuthUser.get(id)
    		conn
    		|> assign(:current_user, user)
    		|> put_session(:current_user_id, user.id)
    	_ -> assign(conn, :current_user, nil)
    		|> put_session(:current_user_id, nil)
  end
  end

  @doc """
  Used for routes that require the user to not be authenticated.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.

  If you want to enforce the user email is confirmed before
  they use the application at all, here would be a good place.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: Routes.<%= schema.route_helper %>_session_path(conn, :new))
      |> halt()
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(_conn), do: "/"
end
