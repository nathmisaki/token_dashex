defmodule TokenDashex.Tips.RepeatedReads do
  @moduledoc """
  Flags files opened by Read/Edit/Write more than 10 times in the last 7 days
  (grouped by target path). Mirrors Python's `repeated_target_tips` repeat-file rule.
  """

  @behaviour TokenDashex.Tips.Rule

  import Ecto.Query

  alias TokenDashex.Repo
  alias TokenDashex.Schema.Tool

  @threshold 10

  @impl true
  def evaluate do
    cutoff = DateTime.utc_now() |> DateTime.add(-7 * 86_400, :second)

    from(t in Tool,
      join: m in assoc(t, :message),
      where:
        t.name in ["Read", "Edit", "Write"] and not is_nil(t.target) and m.timestamp >= ^cutoff,
      group_by: t.target,
      having: count(t.id) > @threshold,
      select: %{
        target: t.target,
        n: count(t.id),
        sessions: count(t.session_id, :distinct)
      },
      order_by: [desc: count(t.id)],
      limit: 10
    )
    |> Repo.all()
    |> Enum.map(fn %{target: target, n: n, sessions: sessions} ->
      short = Path.basename(target)

      %{
        key: "repeat-file:#{target}",
        category: "repeat-file",
        title: "#{short} read #{n} times",
        body:
          "This file was opened #{n} times across #{sessions} sessions in the past 7 days. " <>
            "A summary in CLAUDE.md or one read per session would avoid repeats.",
        scope: target,
        severity: :info
      }
    end)
  end
end
