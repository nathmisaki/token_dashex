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

  @doc """
  Compact human-readable count: 1500 → "1.5K", 2_300_000 → "2.3M".
  """
  @spec compact(integer()) :: String.t()
  def compact(n) when is_integer(n) and n >= 1_000_000_000 do
    short(n / 1_000_000_000) <> "B"
  end

  def compact(n) when is_integer(n) and n >= 1_000_000 do
    short(n / 1_000_000) <> "M"
  end

  def compact(n) when is_integer(n) and n >= 1_000 do
    short(n / 1_000) <> "K"
  end

  def compact(n) when is_integer(n), do: Integer.to_string(n)
  def compact(_), do: "0"

  defp short(f) when is_float(f) do
    if f >= 100,
      do: :erlang.float_to_binary(f, decimals: 0),
      else: :erlang.float_to_binary(f, decimals: 1)
  end

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

  @doc """
  Strips the leading `claude-` prefix from a model id for compact display.
  """
  @spec model_short(String.t() | nil) :: String.t()
  def model_short(nil), do: "unknown"
  def model_short(""), do: "unknown"
  def model_short("claude-" <> rest), do: rest
  def model_short(model), do: model
end
