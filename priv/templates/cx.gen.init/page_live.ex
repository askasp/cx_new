
defmodule <%= inspect context.web_module %>.PageLive do
  use GenauthestWeb, :live_view
  def mount(_, session, socket) do
		user = Map.get(session, "current_user_id")
		|> case do
  		nil -> nil
		  id  -> Genauthest.ReadModel.AuthUser.get(id)
		end
    {:ok, assign(socket, current_user: user)}
  end

  def render(assigns) do
    ~H"""
				<div class="hero bg-base-200 min-h-screen">
  				<div class="text-center hero-content">
    				<div class="max-w-md">
      				<h1 class="mb-5 text-5xl font-bold">
        				Cqrs Generator
          		</h1>
      				<p class="mb-5">
        				Provides federated auth, command and event admin panel
          		</p>
							<ul>
								<li> <a class="link link-primary" href="/cx/admin" >Admin panel </a> </li>
								<li> <a class="link link-secondary" href="/cx/flows" >Flow generator </a> </li>
								<li> <a class="link link" href="/dashboard">LiveDashboard</a> </li>
							</ul>
				    </div>
  				</div>
				</div>
"""
  end
end

