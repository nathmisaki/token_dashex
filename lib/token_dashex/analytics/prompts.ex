defmodule TokenDashex.Analytics.Prompts do
  @moduledoc """
  Lists the user's most expensive prompts. "Expensive" is defined as the sum
  of the assistant turn(s) that immediately followed the user prompt within
  the same session. We approximate that by aggregating per-session totals
  and pairing each user prompt with its session's grand total.
  """

  import Ecto.Query

  alias TokenDashex.Pricing
  alias TokenDashex.Repo
  alias TokenDashex.Schema.Message

  @type sort :: :tokens | :recent

  @type row :: %{
          message_id: String.t(),
          session_id: String.t(),
          project_slug: String.t(),
          prompt_text: String.t() | nil,
          model: String.t() | nil,
          billable_tokens: non_neg_integer(),
          cache_read_tokens: non_neg_integer(),
          cache_creation_5m: non_neg_integer(),
          cache_creation_1h: non_neg_integer(),
          input_tokens: non_neg_integer(),
          output_tokens: non_neg_integer(),
          estimated_cost_usd: float(),
          timestamp: DateTime.t()
        }

  @default_limit 100

  @spec expensive(map()) :: [row]
  def expensive(opts \\ %{}) do
    sort = Map.get(opts, :sort, :tokens)
    limit = Map.get(opts, :limit, @default_limit)
    offset = Map.get(opts, :offset, 0)

    sums =
      from m in Message,
        where: m.role == "assistant",
        group_by: m.session_id,
        select: %{
          session_id: m.session_id,
          model: max(m.model),
          input: coalesce(sum(m.input_tokens), 0),
          output: coalesce(sum(m.output_tokens), 0),
          cache_read: coalesce(sum(m.cache_read_tokens), 0),
          cache_5m: coalesce(sum(m.cache_creation_5m_tokens), 0),
          cache_1h: coalesce(sum(m.cache_creation_1h_tokens), 0),
          cache_total: coalesce(sum(m.cache_creation_tokens), 0),
          billable:
            coalesce(sum(m.input_tokens), 0) +
              coalesce(sum(m.output_tokens), 0) +
              coalesce(sum(m.cache_creation_5m_tokens), 0) +
              coalesce(sum(m.cache_creation_1h_tokens), 0)
        }

    base =
      from u in Message,
        as: :user,
        where: u.role == "user" and not is_nil(u.prompt_text),
        join: s in subquery(sums),
        as: :sums,
        on: s.session_id == u.session_id,
        select: %{
          message_id: u.id,
          session_id: u.session_id,
          project_slug: u.project_slug,
          prompt_text: u.prompt_text,
          model: s.model,
          input_tokens: s.input,
          output_tokens: s.output,
          cache_read_tokens: s.cache_read,
          cache_creation_5m: s.cache_5m,
          cache_creation_1h: s.cache_1h,
          cache_creation_total: s.cache_total,
          billable_tokens: s.billable,
          timestamp: u.timestamp
        }

    base
    |> apply_sort(sort)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
    |> Enum.map(&add_cost/1)
  end

  defp add_cost(row) do
    cost =
      Pricing.cost_for(row.model, %{
        "input_tokens" => row.input_tokens,
        "output_tokens" => row.output_tokens,
        "cache_creation_input_tokens" => row.cache_creation_total,
        "cache_creation_5m_input_tokens" => row.cache_creation_5m,
        "cache_creation_1h_input_tokens" => row.cache_creation_1h,
        "cache_read_input_tokens" => row.cache_read_tokens
      })

    Map.put(row, :estimated_cost_usd, cost)
  end

  defp apply_sort(query, :recent),
    do: from([user: u] in query, order_by: [desc: u.timestamp])

  defp apply_sort(query, _),
    do: from([sums: s] in query, order_by: [desc: s.billable])
end
