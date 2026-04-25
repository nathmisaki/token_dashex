defmodule TokenDashex.Tips.RightSize do
  @moduledoc """
  Detects short Opus turns (output < 500 tokens, not sidechain) in the last 7
  days and estimates savings from switching to Sonnet.
  Mirrors Python's `right_size_tips` rule.
  """

  @behaviour TokenDashex.Tips.Rule

  import Ecto.Query

  alias TokenDashex.Repo
  alias TokenDashex.Schema.Message

  @min_turns 10
  @min_savings 1.0
  @opus_in_price 15.0
  @opus_out_price 75.0
  @sonnet_in_price 3.0
  @sonnet_out_price 15.0

  @impl true
  def evaluate do
    cutoff = DateTime.utc_now() |> DateTime.add(-7 * 86_400, :second)

    result =
      from(m in Message,
        where:
          m.role == "assistant" and
            like(m.model, "%opus%") and
            m.output_tokens < 500 and
            m.is_sidechain == false and
            m.timestamp >= ^cutoff,
        select: %{
          n: count(m.id),
          in_tok:
            coalesce(sum(m.input_tokens), 0) +
              coalesce(sum(m.cache_creation_5m_tokens), 0) +
              coalesce(sum(m.cache_creation_1h_tokens), 0),
          out_tok: coalesce(sum(m.output_tokens), 0)
        }
      )
      |> Repo.one()

    case result do
      %{n: n, in_tok: in_tok, out_tok: out_tok} when n >= @min_turns ->
        opus_cost = (in_tok * @opus_in_price + out_tok * @opus_out_price) / 1_000_000
        sonnet_cost = (in_tok * @sonnet_in_price + out_tok * @sonnet_out_price) / 1_000_000
        savings = opus_cost - sonnet_cost

        if savings >= @min_savings do
          [
            %{
              key: "right-size:opus-short-turns-7d",
              category: "right-size",
              title: "#{n} short Opus turns might fit on Sonnet",
              body:
                "Opus turns under 500 output tokens cost ~$#{Float.round(opus_cost, 2)} in the last 7 days. " <>
                  "Sonnet would have cost ~$#{Float.round(sonnet_cost, 2)} (savings ~$#{Float.round(savings, 2)}).",
              scope: "opus-short-turns-7d",
              severity: :warning
            }
          ]
        else
          []
        end

      _ ->
        []
    end
  end
end
