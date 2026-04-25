defmodule TokenDashex.Analytics.Tools do
  @moduledoc """
  Aggregates tool invocations across the corpus, grouping by tool `name`.
  """

  import Ecto.Query

  alias TokenDashex.Repo
  alias TokenDashex.Schema.{Message, Tool}

  @type row :: %{
          name: String.t(),
          invocations: non_neg_integer(),
          input_tokens: non_neg_integer(),
          output_tokens: non_neg_integer(),
          result_tokens: non_neg_integer()
        }

  @spec breakdown(keyword()) :: [row]
  def breakdown(opts \\ []) do
    since = Keyword.get(opts, :since)

    base =
      from(t in Tool,
        group_by: t.name,
        order_by: [desc: count(t.id)],
        select: %{
          name: t.name,
          invocations: count(t.id),
          input_tokens: coalesce(sum(t.input_tokens), 0),
          output_tokens: coalesce(sum(t.output_tokens), 0),
          result_tokens: coalesce(sum(t.result_tokens), 0)
        }
      )

    base
    |> apply_since(since)
    |> Repo.all()
  end

  defp apply_since(query, nil), do: query

  defp apply_since(query, %DateTime{} = dt) do
    from(t in query,
      join: m in Message,
      on: m.id == t.message_id,
      where: m.timestamp >= ^dt
    )
  end
end
