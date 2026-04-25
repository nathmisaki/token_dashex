defmodule TokenDashex.Tips.OversizedResults do
  @moduledoc """
  Flags tool results over 50k tokens in the last 7 days (tool_name="_tool_result").
  Requires at least 5 occurrences before firing.
  Mirrors Python's `outlier_tips` tool-bloat rule.
  """

  @behaviour TokenDashex.Tips.Rule

  import Ecto.Query

  alias TokenDashex.Repo
  alias TokenDashex.Schema.Tool

  @threshold 50_000
  @min_count 5

  @impl true
  def evaluate do
    cutoff = DateTime.utc_now() |> DateTime.add(-7 * 86_400, :second)

    result =
      from(t in Tool,
        join: m in assoc(t, :message),
        where:
          t.name == "_tool_result" and t.result_tokens > @threshold and m.timestamp >= ^cutoff,
        select: %{
          n: count(t.id),
          avg_t: avg(t.result_tokens)
        }
      )
      |> Repo.one()

    build_tip(result)
  end

  defp build_tip(%{n: n, avg_t: avg_t}) when not is_nil(n) and n >= @min_count do
    avg_int = to_int(avg_t)

    [
      %{
        key: "tool-bloat:result-50k+",
        category: "tool-bloat",
        title: "#{n} tool results over 50k tokens this week",
        body:
          "Average size is #{avg_int} tokens. " <>
            "Pipe long Bash output to head/tail and ask for narrower file reads.",
        scope: "result-50k+",
        severity: :warning
      }
    ]
  end

  defp build_tip(_), do: []

  defp to_int(v) when is_struct(v, Decimal), do: v |> Decimal.to_float() |> round()
  defp to_int(v) when is_float(v), do: round(v)
  defp to_int(v) when is_integer(v), do: v
  defp to_int(nil), do: 0
end
