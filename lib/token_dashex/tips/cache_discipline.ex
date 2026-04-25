defmodule TokenDashex.Tips.CacheDiscipline do
  @moduledoc """
  Flags low cache-hit ratio over the last 7 days. Hit ratio is
  cache_read / (cache_read + cache_creation); below 0.5 we suggest reusing
  prompts to take advantage of Anthropic's cache pricing.
  """

  @behaviour TokenDashex.Tips.Rule

  import Ecto.Query

  alias TokenDashex.Repo
  alias TokenDashex.Schema.Message

  @key "cache_discipline"
  @threshold 0.5

  @impl true
  def evaluate do
    cutoff = Date.utc_today() |> Date.add(-7) |> Date.to_iso8601()

    %{cache_read: read, cache_create: create} =
      from(m in Message,
        where: fragment("date(?)", m.timestamp) >= ^cutoff,
        select: %{
          cache_read: coalesce(sum(m.cache_read_tokens), 0),
          cache_create: coalesce(sum(m.cache_creation_tokens), 0)
        }
      )
      |> Repo.one()

    total = read + create

    if total > 0 and read / total < @threshold do
      [
        %{
          key: @key,
          title: "Cache hit rate is low",
          body:
            "Only #{Float.round(read / total * 100, 1)}% of cacheable input tokens hit the prompt cache over the last 7 days. " <>
              "Reusing the same system prompts and reading large files via cached prefixes will lower cost.",
          severity: :warning
        }
      ]
    else
      []
    end
  end
end
