defmodule TokenDashex.Tips.RepeatedReads do
  @moduledoc """
  Flags sessions where the same `Read`-tool target is invoked more than five
  times. Produces one tip per offending session (like the Python dashboard's
  per-file tips), ordered by read count descending.
  """

  @behaviour TokenDashex.Tips.Rule

  import Ecto.Query

  alias TokenDashex.Repo
  alias TokenDashex.Schema.Tool

  @threshold 5

  @impl true
  def evaluate do
    cutoff = DateTime.utc_now() |> DateTime.add(-7 * 86_400, :second)

    from(t in Tool,
      join: m in assoc(t, :message),
      where: t.name == "Read" and m.timestamp >= ^cutoff,
      group_by: t.session_id,
      having: count(t.id) > @threshold,
      select: %{session_id: t.session_id, count: count(t.id)},
      order_by: [desc: count(t.id)],
      limit: 10
    )
    |> Repo.all()
    |> Enum.map(fn %{session_id: id, count: c} ->
      short = String.slice(id, 0, 8)

      %{
        key: "repeat-file:#{id}",
        category: "repeat-file",
        title: "Session #{short}… re-reads files heavily",
        body:
          "This session called Read #{c} times. Reading the same context repeatedly " <>
            "burns input tokens. Consider caching or splitting tasks across sessions.",
        scope: id,
        severity: :info
      }
    end)
  end
end
