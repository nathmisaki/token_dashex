defmodule TokenDashex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  use Boundary, top_level?: true, deps: [TokenDashex, TokenDashexWeb]

  @impl true
  def start(_type, _args) do
    TokenDashex.Pricing.reload!()

    children = [
      TokenDashexWeb.Telemetry,
      TokenDashex.Repo,
      {DNSCluster, query: Application.get_env(:token_dashex, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TokenDashex.PubSub},
      scanner_child(),
      TokenDashexWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: TokenDashex.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    TokenDashexWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp scanner_child do
    {TokenDashex.Scanner.Worker,
     root: TokenDashex.Paths.projects_dir(),
     interval: Application.get_env(:token_dashex, :scanner_interval_ms, 30_000),
     auto_tick: Application.get_env(:token_dashex, :scanner_auto_tick, true)}
  end
end
