defmodule TokenDashex.Analytics.Prompts do
  @moduledoc """
  Lists the user's most expensive prompts. "Expensive" is defined as the sum
  of the assistant turn(s) that immediately followed the user prompt within
  the same session. We approximate that by aggregating per-session totals
  and pairing each user prompt with its session's grand total.
  """

  import Ecto.Query

  alias TokenDashex.Repo
  alias TokenDashex.Schema.Message

  @type sort :: :input | :output | :total

  @type row :: %{
          message_id: String.t(),
          session_id: String.t(),
          project_slug: String.t(),
          prompt_text: String.t() | nil,
          input_tokens: non_neg_integer(),
          output_tokens: non_neg_integer(),
          total_tokens: non_neg_integer(),
          timestamp: DateTime.t()
        }

  @default_limit 50

  @spec expensive(map()) :: [row]
  def expensive(opts \\ %{}) do
    sort = Map.get(opts, :sort, :total)
    limit = Map.get(opts, :limit, @default_limit)
    offset = Map.get(opts, :offset, 0)

    sums =
      from m in Message,
        where: m.role == "assistant",
        group_by: m.session_id,
        select: %{
          session_id: m.session_id,
          input: coalesce(sum(m.input_tokens), 0),
          output: coalesce(sum(m.output_tokens), 0),
          total:
            coalesce(sum(m.input_tokens), 0) + coalesce(sum(m.output_tokens), 0) +
              coalesce(sum(m.cache_creation_tokens), 0) +
              coalesce(sum(m.cache_read_tokens), 0)
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
          input_tokens: s.input,
          output_tokens: s.output,
          total_tokens: s.total,
          timestamp: u.timestamp
        }

    base
    |> apply_sort(sort)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  defp apply_sort(query, :input),
    do: from([sums: s] in query, order_by: [desc: s.input])

  defp apply_sort(query, :output),
    do: from([sums: s] in query, order_by: [desc: s.output])

  defp apply_sort(query, _),
    do: from([sums: s] in query, order_by: [desc: s.total])
end
