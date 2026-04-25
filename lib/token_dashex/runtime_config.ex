defmodule TokenDashex.RuntimeConfig do
  @moduledoc """
  Helpers used by `config/runtime.exs` so the prod release can boot without
  hand-set environment variables. token_dashex is a single-user local tool,
  so we persist a generated `SECRET_KEY_BASE` on first launch and bind to
  loopback by default.
  """

  @doc """
  Returns a stable secret. Reads `path` if it already holds a 64+ byte
  secret, otherwise generates and persists a fresh one with mode 0600.
  """
  @spec ensure_persistent_secret(String.t()) :: String.t()
  def ensure_persistent_secret(path) do
    path |> Path.dirname() |> File.mkdir_p!()

    case File.read(path) do
      {:ok, contents} when byte_size(contents) >= 64 ->
        String.trim(contents)

      _ ->
        secret = 64 |> :crypto.strong_rand_bytes() |> Base.encode64(padding: false)
        File.write!(path, secret)
        File.chmod!(path, 0o600)
        secret
    end
  end

  @doc """
  Resolves a string-or-nil bind address into the tuple form Bandit expects.
  Defaults to loopback so the dashboard never accidentally exposes Claude
  Code session contents on the network.
  """
  @spec bind_ip(String.t() | nil) :: :inet.ip_address()
  def bind_ip(nil), do: {127, 0, 0, 1}

  def bind_ip(value) do
    case :inet.parse_address(String.to_charlist(value)) do
      {:ok, ip} -> ip
      _ -> {127, 0, 0, 1}
    end
  end
end
