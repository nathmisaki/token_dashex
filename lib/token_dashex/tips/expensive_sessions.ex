defmodule TokenDashex.Tips.ExpensiveSessions do
  @moduledoc """
  Surfaces sessions costing more than $1 USD so the user can investigate.
  Produces one tip per expensive session (like the Python dashboard).
  """

  @behaviour TokenDashex.Tips.Rule

  alias TokenDashex.Analytics.Sessions
  alias TokenDashex.Pricing

  @min_cost 1.0

  @impl true
  def evaluate do
    Sessions.recent(%{limit: 100})
    |> Enum.map(&with_cost/1)
    |> Enum.filter(&(&1.cost > @min_cost))
    |> Enum.sort_by(& &1.cost, :desc)
    |> Enum.take(10)
    |> Enum.map(fn r ->
      short = String.slice(r.session_id, 0, 8)
      project = r.project_slug || "unknown"

      %{
        key: "cost-spike:#{r.session_id}",
        category: "cost-spike",
        title: "Expensive session in #{project}",
        body:
          "Session #{short}... cost $#{Float.round(r.cost, 2)}. " <>
            "Take a look at what drove the cost in this session.",
        scope: r.session_id,
        severity: :info
      }
    end)
  end

  defp with_cost(row) do
    cost =
      Pricing.cost_for(nil, %{
        "input_tokens" => row.input,
        "output_tokens" => row.output,
        "cache_creation_input_tokens" => row.cache_create,
        "cache_read_input_tokens" => row.cache_read
      })

    Map.put(row, :cost, cost)
  end
end
