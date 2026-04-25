defmodule TokenDashex.Analytics.Overview do
  @moduledoc """
  Aggregates the headline numbers shown on the dashboard's Overview tab:
  total tokens by class, distinct session and project counts, broken into
  all-time / today / last-7-days windows.
  """

  import Ecto.Query

  alias TokenDashex.Pricing
  alias TokenDashex.Repo
  alias TokenDashex.Schema.Message

  @type window :: %{
          input: non_neg_integer(),
          output: non_neg_integer(),
          cache_create: non_neg_integer(),
          cache_read: non_neg_integer(),
          sessions: non_neg_integer(),
          projects: non_neg_integer(),
          cost: float()
        }

  @type totals :: %{all_time: window(), today: window(), last_7d: window()}

  @spec totals() :: totals()
  def totals do
    today = Date.utc_today()
    seven_days_ago = Date.add(today, -7)

    %{
      all_time: window_query(nil),
      today: window_query({:eq, today}),
      last_7d: window_query({:gte, seven_days_ago})
    }
  end

  defp window_query(filter) do
    base =
      from m in Message,
        select: %{
          input: coalesce(sum(m.input_tokens), 0),
          output: coalesce(sum(m.output_tokens), 0),
          cache_create: coalesce(sum(m.cache_creation_tokens), 0),
          cache_read: coalesce(sum(m.cache_read_tokens), 0),
          sessions: count(fragment("DISTINCT ?", m.session_id)),
          projects: count(fragment("DISTINCT ?", m.project_slug))
        }

    base
    |> apply_filter(filter)
    |> Repo.one()
    |> Map.merge(%{cost: total_cost(filter)})
  end

  defp apply_filter(query, nil), do: query

  defp apply_filter(query, {:eq, %Date{} = day}) do
    from m in query, where: fragment("date(?)", m.timestamp) == ^Date.to_iso8601(day)
  end

  defp apply_filter(query, {:gte, %Date{} = day}) do
    from m in query, where: fragment("date(?)", m.timestamp) >= ^Date.to_iso8601(day)
  end

  defp total_cost(filter) do
    from(m in Message,
      group_by: m.model,
      select: %{
        model: m.model,
        input: coalesce(sum(m.input_tokens), 0),
        output: coalesce(sum(m.output_tokens), 0),
        cache_create: coalesce(sum(m.cache_creation_tokens), 0),
        cache_read: coalesce(sum(m.cache_read_tokens), 0)
      }
    )
    |> apply_filter(filter)
    |> Repo.all()
    |> Enum.reduce(0.0, fn row, acc ->
      acc +
        Pricing.cost_for(row.model, %{
          "input_tokens" => row.input,
          "output_tokens" => row.output,
          "cache_creation_input_tokens" => row.cache_create,
          "cache_read_input_tokens" => row.cache_read
        })
    end)
  end
end
