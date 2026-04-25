defmodule TokenDashex.Tips.SubagentOutlier do
  @moduledoc """
  Detects subagent invocations (is_sidechain=true) where the most expensive
  run is more than 6x the average and over 50k tokens — signals an outlier
  that's worth investigating.
  Mirrors Python's `outlier_tips` subagent-outlier rule.
  """

  @behaviour TokenDashex.Tips.Rule

  import Ecto.Query

  alias TokenDashex.Repo
  alias TokenDashex.Schema.Message

  @min_invocations 10
  @outlier_multiplier 6
  @min_tokens 50_000

  @impl true
  def evaluate do
    cutoff = DateTime.utc_now() |> DateTime.add(-7 * 86_400, :second)

    from(m in Message,
      where:
        m.is_sidechain == true and
          not is_nil(m.agent_id) and
          m.timestamp >= ^cutoff,
      group_by: m.agent_id,
      having: count(m.id) >= @min_invocations,
      select: %{
        agent_id: m.agent_id,
        n: count(m.id),
        mean_t: avg(m.input_tokens + m.output_tokens),
        max_t: max(m.input_tokens + m.output_tokens)
      }
    )
    |> Repo.all()
    |> Enum.filter(fn %{mean_t: mean_t, max_t: max_t} ->
      mean_f = decimal_to_float(mean_t)
      max_t > @outlier_multiplier * mean_f and max_t > @min_tokens
    end)
    |> Enum.map(fn %{agent_id: agent_id, mean_t: mean_t, max_t: max_t} ->
      mean_int = mean_t |> decimal_to_float() |> round()
      short = String.slice(agent_id, 0, 12)

      %{
        key: "subagent-outlier:#{agent_id}",
        category: "subagent-outlier",
        title: "Subagent #{short} has cost outliers",
        body:
          "Largest invocation used #{max_t} tokens vs mean #{mean_int}. " <>
            "Worth checking what those did differently.",
        scope: agent_id,
        severity: :warning
      }
    end)
  end

  defp decimal_to_float(v) when is_struct(v, Decimal), do: Decimal.to_float(v)
  defp decimal_to_float(v) when is_float(v), do: v
  defp decimal_to_float(v) when is_integer(v), do: v * 1.0
  defp decimal_to_float(nil), do: 0.0
end
