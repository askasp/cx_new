

  scope <%= router_scope %> do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/log_in", <%= inspect schema.alias %>SessionController, :new
    post "/users/log_in", <%= inspect schema.alias %>SessionController, :create
  end

  scope <%= router_scope %> do
    pipe_through [:browser]

    delete "/users/log_out", <%= inspect schema.alias %>SessionController, :delete
  end


  scope <%= router_scope %> do
    pipe_through [:browser, :redirect_if_user_is_authenticated]
    get "/:provider", UserOauthController, :request
    get "/:provider/callback", UserOauthController, :callback
  end
