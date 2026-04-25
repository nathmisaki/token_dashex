import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.

if System.get_env("PHX_SERVER") do
  config :token_dashex, TokenDashexWeb.Endpoint, server: true
end

if config_env() == :prod do
  alias TokenDashex.RuntimeConfig

  database =
    System.get_env("TOKEN_DASHEX_DB") ||
      Path.expand("~/.claude/token-dashex.db")

  database |> Path.dirname() |> File.mkdir_p!()

  config :token_dashex, TokenDashex.Repo,
    database: database,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5"),
    journal_mode: :wal

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      RuntimeConfig.ensure_persistent_secret(
        Path.join(Path.dirname(database), "secret_key_base")
      )

  host = System.get_env("PHX_HOST") || "localhost"
  port = String.to_integer(System.get_env("PORT") || "4000")
  bind = RuntimeConfig.bind_ip(System.get_env("BIND_ADDRESS"))

  config :token_dashex, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :token_dashex, TokenDashexWeb.Endpoint,
    url: [host: host, port: port, scheme: "http"],
    http: [ip: bind, port: port],
    secret_key_base: secret_key_base
end
