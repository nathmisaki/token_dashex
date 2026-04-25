defmodule TokenDashex.Analytics.ByModel do
  @moduledoc """
  Per-model token totals + cost based on the active pricing table.
  """

  import Ecto.Query

  alias TokenDashex.Pricing
  alias TokenDashex.Repo
  alias TokenDashex.Schema.Message

  @type row :: %{
          model: String.t(),
          input: non_neg_integer(),
          output: non_neg_integer(),
          cache_create: non_neg_integer(),
          cache_read: non_neg_integer(),
          cost: float()
        }

  @spec breakdown() :: [row]
  def breakdown do
    from(m in Message,
      where: not is_nil(m.model),
      group_by: m.model,
      order_by: [desc: sum(m.input_tokens) + sum(m.output_tokens)],
      select: %{
        model: m.model,
        input: coalesce(sum(m.input_tokens), 0),
        output: coalesce(sum(m.output_tokens), 0),
        cache_create: coalesce(sum(m.cache_creation_tokens), 0),
        cache_read: coalesce(sum(m.cache_read_tokens), 0)
      }
    )
    |> Repo.all()
    |> Enum.map(fn row ->
      Map.put(
        row,
        :cost,
        Pricing.cost_for(row.model, %{
          "input_tokens" => row.input,
          "output_tokens" => row.output,
          "cache_creation_input_tokens" => row.cache_create,
          "cache_read_input_tokens" => row.cache_read
        })
      )
    end)
  end
end
