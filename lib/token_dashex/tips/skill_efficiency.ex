defmodule TokenDashex.Tips.SkillEfficiency do
  @moduledoc """
  Compares per-skill mean tokens-per-invocation. Slugs that consume more than
  two standard deviations above the cohort mean are flagged.
  """

  @behaviour TokenDashex.Tips.Rule

  alias TokenDashex.Skills

  @key "skill_efficiency"

  @impl true
  def evaluate do
    rows =
      Skills.usage_breakdown()
      |> Enum.filter(&(&1.invocations > 0))
      |> Enum.map(fn r ->
        Map.put(r, :avg, r.est_tokens / r.invocations)
      end)

    case rows do
      [] ->
        []

      [_only] ->
        []

      _ ->
        avgs = Enum.map(rows, & &1.avg)
        mean = Enum.sum(avgs) / length(avgs)
        std = std_dev(avgs, mean)

        outliers = Enum.filter(rows, &(&1.avg > mean + 2 * std))

        case outliers do
          [] -> []
          _ -> [build_tip(outliers)]
        end
    end
  end

  defp build_tip(outliers) do
    body =
      outliers
      |> Enum.map(fn r ->
        "  - #{r.slug}: ~#{round(r.avg)} tokens / invocation"
      end)
      |> Enum.join("\n")

    %{
      key: @key,
      category: "skill-bloat",
      title: "Some skills are token-heavy",
      body: "These skills consume disproportionately more tokens per use:\n#{body}",
      severity: :info
    }
  end

  defp std_dev(values, mean) do
    n = length(values)

    sum_sq =
      Enum.reduce(values, 0.0, fn v, acc ->
        acc + :math.pow(v - mean, 2)
      end)

    :math.sqrt(sum_sq / n)
  end
end
