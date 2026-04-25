defmodule TokenDashex.Tips.SkillEfficiency do
  @moduledoc """
  Compares per-skill mean tokens-per-invocation. Slugs that consume more than
  two standard deviations above the cohort mean are flagged. Produces one tip
  per outlier skill.
  """

  @behaviour TokenDashex.Tips.Rule

  alias TokenDashex.Skills

  @impl true
  def evaluate do
    rows =
      Skills.usage_breakdown()
      |> Enum.filter(&(&1.invocations > 0))
      |> Enum.map(fn r ->
        Map.put(r, :avg, r.est_tokens / r.invocations)
      end)

    case rows do
      [] -> []
      [_only] -> []
      _ -> find_outliers(rows)
    end
  end

  defp find_outliers(rows) do
    avgs = Enum.map(rows, & &1.avg)
    mean = Enum.sum(avgs) / length(avgs)
    std = std_dev(avgs, mean)

    rows
    |> Enum.filter(&(&1.avg > mean + 2 * std))
    |> Enum.map(fn r ->
      %{
        key: "skill-bloat:#{r.slug}",
        category: "skill-bloat",
        title: "#{r.slug} is token-heavy",
        body:
          "This skill consumes ~#{round(r.avg)} tokens per invocation, " <>
            "which is significantly above the cohort average.",
        scope: r.slug,
        severity: :info
      }
    end)
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
