defmodule TokenDashex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TokenDashexWeb.Telemetry,
      TokenDashex.Repo,
      {DNSCluster, query: Application.get_env(:token_dashex, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TokenDashex.PubSub},
      # Start a worker by calling: TokenDashex.Worker.start_link(arg)
      # {TokenDashex.Worker, arg},
      # Start to serve requests, typically the last entry
      TokenDashexWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TokenDashex.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TokenDashexWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
