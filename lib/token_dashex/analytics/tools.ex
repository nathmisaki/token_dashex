defmodule TokenDashex.Analytics.Tools do
  @moduledoc """
  Aggregates tool invocations across the corpus, grouping by tool `name`.
  """

  import Ecto.Query

  alias TokenDashex.Repo
  alias TokenDashex.Schema.Tool

  @type row :: %{
          name: String.t(),
          invocations: non_neg_integer(),
          input_tokens: non_neg_integer(),
          output_tokens: non_neg_integer(),
          result_tokens: non_neg_integer()
        }

  @spec breakdown() :: [row]
  def breakdown do
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
    |> Repo.all()
  end
end
