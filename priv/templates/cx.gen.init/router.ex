defmodule <%= inspect context.web_module %>.Router do
    use <%= inspect context.web_module %>, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {<%= inspect context.web_module %>.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", <%= inspect context.web_module %> do
    pipe_through :browser
    live "/", PageLive, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", <%%= inspect context.web_module %> do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: <%= inspect context.web_module %>.Telemetry
    end
  end

  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
  scope "/cx", CxNewWeb do
    pipe_through([:browser])

    live("/admin", AdminLive, :index)
    live("/flows", CanvasLive, :index)
    live("/flows/:flow", CanvasLive, :show)

  end

end
