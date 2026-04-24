defmodule TokenDashex.Repo do
  use Ecto.Repo,
    otp_app: :token_dashex,
    adapter: Ecto.Adapters.Postgres
end
