defmodule TokenDashex.Tips do
  @moduledoc """
  Dispatches each rule, filters out tips dismissed within the trailing 14
  days, and persists fresh dismissals.
  """

  import Ecto.Query

  alias TokenDashex.Repo
  alias TokenDashex.Schema.DismissedTip

  @default_rules [
    TokenDashex.Tips.CacheDiscipline,
    TokenDashex.Tips.RepeatedReads,
    TokenDashex.Tips.RepeatBash,
    TokenDashex.Tips.RightSize,
    TokenDashex.Tips.OversizedResults,
    TokenDashex.Tips.SubagentOutlier
  ]

  @dismiss_window_seconds 14 * 86_400

  @spec active() :: [TokenDashex.Tips.Rule.tip()]
  def active(rules \\ @default_rules) do
    dismissed = active_dismissals()

    rules
    |> Enum.flat_map(& &1.evaluate())
    |> Enum.reject(&MapSet.member?(dismissed, &1.key))
  end

  @spec dismiss(String.t()) :: :ok
  def dismiss(key) do
    %DismissedTip{}
    |> DismissedTip.changeset(%{key: key, dismissed_at: DateTime.utc_now()})
    |> Repo.insert(on_conflict: :replace_all, conflict_target: :key)

    :ok
  end

  defp active_dismissals do
    cutoff = DateTime.utc_now() |> DateTime.add(-@dismiss_window_seconds, :second)

    from(d in DismissedTip, where: d.dismissed_at >= ^cutoff, select: d.key)
    |> Repo.all()
    |> MapSet.new()
  end
end
