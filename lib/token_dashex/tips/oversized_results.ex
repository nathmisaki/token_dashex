defmodule TokenDashex.Tips.OversizedResults do
  @moduledoc """
  Flags tool invocations whose estimated result token count exceeds 50k.
  Reading such large blobs once is fine; doing it routinely is a smell.
  """

  @behaviour TokenDashex.Tips.Rule

  import Ecto.Query

  alias TokenDashex.Repo
  alias TokenDashex.Schema.Tool

  @key "oversized_results"
  @threshold 50_000

  @impl true
  def evaluate do
    count =
      from(t in Tool, where: t.result_tokens > @threshold, select: count(t.id))
      |> Repo.one()

    if count > 0 do
      [
        %{
          key: @key,
          category: "tool-bloat",
          title: "Tool calls returned very large results",
          body:
            "#{count} tool invocations returned more than #{@threshold} estimated tokens. " <>
              "Pass narrower paths or stream the data instead of loading whole files.",
          severity: :warning
        }
      ]
    else
      []
    end
  end
end
