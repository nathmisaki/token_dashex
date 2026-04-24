defmodule TokenDashex.Repo do
  use Ecto.Repo,
    otp_app: :token_dashex,
    adapter: Ecto.Adapters.SQLite3
end
