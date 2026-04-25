defmodule TokenDashex.Tips.ExpensiveSessions do
  @moduledoc """
  Surfaces the top five sessions by USD cost so the user can investigate.
  """

  @behaviour TokenDashex.Tips.Rule

  alias TokenDashex.Analytics.Sessions
  alias TokenDashex.Pricing

  @key "expensive_sessions"

  @impl true
  def evaluate do
    rows =
      Sessions.recent(%{limit: 100})
      |> Enum.map(&with_cost/1)
      |> Enum.sort_by(& &1.cost, :desc)
      |> Enum.take(5)
      |> Enum.filter(&(&1.cost > 1.0))

    case rows do
      [] ->
        []

      sessions ->
        body =
          sessions
          |> Enum.map(fn r ->
            "  - #{String.slice(r.session_id, 0, 8)}… (#{r.project_slug}): " <>
              "$#{Float.round(r.cost, 2)}"
          end)
          |> Enum.join("\n")

        [
          %{
            key: @key,
            category: "cost-spike",
            title: "Most expensive recent sessions",
            body: "Take a look at these and see what drove the cost:\n#{body}",
            severity: :info
          }
        ]
    end
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
