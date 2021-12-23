defmodule CxNew.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      CxNewWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: CxNew.PubSub},
      CxNew.EventStoreDbClient,
      # Start the Endpoint (http/https)
      CxNewWeb.Endpoint,
      {DynamicSupervisor, strategy: :one_for_one, name: AggregateSupervisor},
      {Registry, keys: :unique, name: AggregateRegistry},

      # Start a worker by calling: CxNew.Worker.start_link(arg)
      # {CxNew.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CxNew.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CxNewWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
