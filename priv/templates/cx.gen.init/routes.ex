
  scope "/cx", CxNewWeb do
      pipe_through([:browser])

    live("/admin", AdminLive, :index)
    live("/flows", CanvasLive, :index)
    live("/flows/:flow", CanvasLive, :show)

  end
