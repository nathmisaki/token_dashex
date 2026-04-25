defmodule TokenDashex.Tips.RepeatedReads do
  @moduledoc """
  Flags sessions where the same `Read`-tool target is invoked more than five
  times. Heuristic: counts identical tool name + message_id; the underlying
  arg path is not stored, so this is a coarse early signal.
  """

  @behaviour TokenDashex.Tips.Rule

  import Ecto.Query

  alias TokenDashex.Repo
  alias TokenDashex.Schema.Tool

  @key "repeated_reads"
  @threshold 5

  @impl true
  def evaluate do
    rows =
      from(t in Tool,
        where: t.name == "Read",
        group_by: t.session_id,
        having: count(t.id) > @threshold,
        select: %{session_id: t.session_id, count: count(t.id)},
        order_by: [desc: count(t.id)],
        limit: 5
      )
      |> Repo.all()

    case rows do
      [] ->
        []

      sessions ->
        body =
          sessions
          |> Enum.map(fn %{session_id: id, count: c} ->
            "  - session #{String.slice(id, 0, 8)}…: #{c} reads"
          end)
          |> Enum.join("\n")

        [
          %{
            key: @key,
            title: "Some sessions re-read files heavily",
            body:
              "Reading the same context repeatedly burns input tokens. Consider caching " <>
                "or splitting tasks across sessions:\n#{body}",
            severity: :info
          }
        ]
    end
  end
end
