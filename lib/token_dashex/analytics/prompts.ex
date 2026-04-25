defmodule TokenDashex.Analytics.Prompts do
  @moduledoc """
  Lists the user's most expensive prompts.

  Each row pairs a user message with its immediate assistant response via
  `parent_uuid` (the same join the Python token-dashboard uses). This gives
  per-prompt token counts rather than whole-session aggregates.
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
          cache_creation_total: non_neg_integer(),
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

    base =
      from u in Message,
        as: :user,
        where: u.role == "user" and not is_nil(u.prompt_text) and not is_nil(u.uuid),
        join: a in Message,
        as: :assistant,
        on: a.role == "assistant" and a.parent_uuid == u.uuid,
        select: %{
          message_id: u.id,
          session_id: u.session_id,
          project_slug: u.project_slug,
          prompt_text: u.prompt_text,
          model: a.model,
          input_tokens: a.input_tokens,
          output_tokens: a.output_tokens,
          cache_read_tokens: a.cache_read_tokens,
          cache_creation_5m: a.cache_creation_5m_tokens,
          cache_creation_1h: a.cache_creation_1h_tokens,
          cache_creation_total: a.cache_creation_tokens,
          billable_tokens:
            a.input_tokens + a.output_tokens + a.cache_creation_5m_tokens +
              a.cache_creation_1h_tokens,
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
    # Matches Python: estimated_cost_usd = cache read cost only, not full prompt cost.
    # input/output are 0 so the column reflects cache savings, not total spend.
    cost =
      Pricing.cost_for(row.model, %{
        "input_tokens" => 0,
        "output_tokens" => 0,
        "cache_creation_input_tokens" => 0,
        "cache_creation_5m_input_tokens" => 0,
        "cache_creation_1h_input_tokens" => 0,
        "cache_read_input_tokens" => row.cache_read_tokens
      })

    Map.put(row, :estimated_cost_usd, cost)
  end

  defp apply_sort(query, :recent),
    do: from([user: u] in query, order_by: [desc: u.timestamp])

  defp apply_sort(query, _),
    do:
      from([assistant: a] in query,
        order_by: [
          desc:
            a.input_tokens + a.output_tokens + a.cache_creation_5m_tokens +
              a.cache_creation_1h_tokens
        ]
      )
end
