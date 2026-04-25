defmodule TokenDashex.Tips.RepeatBash do
  @moduledoc """
  Flags Bash commands that run more than 15 times in the last 7 days.
  Mirrors Python's `repeated_target_tips` repeat-bash rule.
  """

  @behaviour TokenDashex.Tips.Rule

  import Ecto.Query

  alias TokenDashex.Repo
  alias TokenDashex.Schema.Tool

  @threshold 15

  @impl true
  def evaluate do
    cutoff = DateTime.utc_now() |> DateTime.add(-7 * 86_400, :second)

    from(t in Tool,
      join: m in assoc(t, :message),
      where: t.name == "Bash" and not is_nil(t.target) and m.timestamp >= ^cutoff,
      group_by: t.target,
      having: count(t.id) > @threshold,
      select: %{target: t.target, n: count(t.id)},
      order_by: [desc: count(t.id)],
      limit: 10
    )
    |> Repo.all()
    |> Enum.map(fn %{target: target, n: n} ->
      cmd = String.slice(target, 0, 60)

      %{
        key: "repeat-bash:#{target}",
        category: "repeat-bash",
        title: "`#{cmd}` ran #{n} times",
        body:
          "This bash command ran #{n} times in the past 7 days. " <>
            "Consider a watch flag or shell alias.",
        scope: target,
        severity: :info
      }
    end)
  end
end
