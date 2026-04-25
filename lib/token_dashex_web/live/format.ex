defmodule TokenDashexWeb.Live.Format do
  @moduledoc false

  @spec tokens(integer()) :: String.t()
  def tokens(n) when is_integer(n) do
    n
    |> Integer.to_charlist()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.intersperse(?,)
    |> List.flatten()
    |> Enum.reverse()
    |> List.to_string()
  end

  def tokens(_), do: "0"

  @spec usd(number()) :: String.t()
  def usd(n) when is_number(n) do
    "$" <> :erlang.float_to_binary(n * 1.0, decimals: 2)
  end

  def usd(_), do: "$0.00"

  @spec date(DateTime.t() | nil) :: String.t()
  def date(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  def date(_), do: "—"

  @spec short_id(String.t() | nil) :: String.t()
  def short_id(nil), do: "—"
  def short_id(id), do: String.slice(id, 0, 8)
end
