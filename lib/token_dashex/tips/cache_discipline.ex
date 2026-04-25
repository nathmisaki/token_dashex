defmodule TokenDashex.Tips.CacheDiscipline do
  @moduledoc """
  Flags low cache-hit ratio per project over the last 7 days. Hit ratio is
  cache_read / (cache_read + cache_creation); below 0.4 we suggest reusing
  prompts to take advantage of Anthropic's cache pricing. Produces one tip
  per offending project (like the Python dashboard).
  """

  @behaviour TokenDashex.Tips.Rule

  import Ecto.Query

  alias TokenDashex.Repo
  alias TokenDashex.Schema.Message

  @threshold 0.40

  @impl true
  def evaluate do
    cutoff = DateTime.utc_now() |> DateTime.add(-7 * 86_400, :second)

    rows =
      from(m in Message,
        where: m.timestamp >= ^cutoff,
        group_by: m.project_slug,
        select: %{
          project_slug: m.project_slug,
          cache_read: coalesce(sum(m.cache_read_tokens), 0),
          cache_create: coalesce(sum(m.cache_creation_tokens), 0)
        }
      )
      |> Repo.all()

    rows
    |> Enum.filter(fn %{cache_read: r, cache_create: c} ->
      total = r + c
      total > 100_000 and r / total < @threshold
    end)
    |> Enum.map(fn %{project_slug: slug, cache_read: r, cache_create: c} ->
      total = r + c
      hit = Float.round(r / total * 100, 1)
      project = slug || "unknown"

      %{
        key: "cache:#{project}",
        category: "cache",
        title: "Low cache hit rate in #{project}",
        body:
          "Cache hit rate is #{hit}% over the last 7 days. Sessions that restart context " <>
            "frequently rebuild cache. Consider longer-lived sessions or fewer context resets.",
        scope: project,
        severity: :warning
      }
    end)
  end
end
