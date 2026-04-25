defmodule TokenDashex.Analytics.Daily do
  @moduledoc """
  Daily token volume time-series, used by the overview chart.
  """

  import Ecto.Query

  alias TokenDashex.Pricing
  alias TokenDashex.Repo
  alias TokenDashex.Schema.Message

  @type row :: %{
          date: Date.t(),
          input: non_neg_integer(),
          output: non_neg_integer(),
          cache_create: non_neg_integer(),
          cache_read: non_neg_integer(),
          cost: float()
        }

  @doc """
  Returns one row per day. Pass an integer to look back N days, or
  `since: DateTime.t() | nil` for an explicit cutoff (`nil` = all time).
  """
  @spec series(non_neg_integer() | keyword()) :: [row]
  def series(arg \\ 30)

  def series(days) when is_integer(days) do
    cutoff_date = Date.utc_today() |> Date.add(-days)
    fetch_with_filter({:gte, cutoff_date})
  end

  def series(opts) when is_list(opts) do
    case Keyword.get(opts, :since) do
      nil -> fetch_with_filter(nil)
      %DateTime{} = dt -> fetch_with_filter({:since, dt})
    end
  end

  defp fetch_with_filter(filter) do
    base =
      from(m in Message,
        group_by: [fragment("date(?)", m.timestamp), m.model],
        order_by: [asc: fragment("date(?)", m.timestamp)],
        select: %{
          date: fragment("date(?)", m.timestamp),
          model: m.model,
          input: coalesce(sum(m.input_tokens), 0),
          output: coalesce(sum(m.output_tokens), 0),
          cache_create: coalesce(sum(m.cache_creation_tokens), 0),
          cache_read: coalesce(sum(m.cache_read_tokens), 0)
        }
      )

    base
    |> apply_filter(filter)
    |> Repo.all()
    |> Enum.group_by(& &1.date)
    |> Enum.map(fn {date_str, day_rows} ->
      cost =
        Enum.reduce(day_rows, 0.0, fn r, acc ->
          acc +
            Pricing.cost_for(r.model, %{
              "input_tokens" => r.input,
              "output_tokens" => r.output,
              "cache_creation_input_tokens" => r.cache_create,
              "cache_read_input_tokens" => r.cache_read
            })
        end)

      %{
        date: parse_date(date_str),
        input: Enum.reduce(day_rows, 0, &(&1.input + &2)),
        output: Enum.reduce(day_rows, 0, &(&1.output + &2)),
        cache_create: Enum.reduce(day_rows, 0, &(&1.cache_create + &2)),
        cache_read: Enum.reduce(day_rows, 0, &(&1.cache_read + &2)),
        cost: cost
      }
    end)
    |> Enum.sort_by(& &1.date, Date)
  end

  defp apply_filter(query, nil), do: query

  defp apply_filter(query, {:gte, %Date{} = day}) do
    from m in query, where: fragment("date(?)", m.timestamp) >= ^Date.to_iso8601(day)
  end

  defp apply_filter(query, {:since, %DateTime{} = dt}) do
    from m in query, where: m.timestamp >= ^dt
  end

  defp parse_date(str) when is_binary(str), do: Date.from_iso8601!(str)
  defp parse_date(%Date{} = d), do: d
end
