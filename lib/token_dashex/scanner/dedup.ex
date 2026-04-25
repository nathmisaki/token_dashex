defmodule TokenDashex.Scanner.Dedup do
  @moduledoc """
  Collapses streaming snapshot duplicates emitted by Claude Code.

  Each streaming token write produces a fresh JSONL line with the same
  `(session_id, message_id)` and growing usage/content. The last write wins;
  earlier snapshots are discarded so totals match API billing.
  """

  alias TokenDashex.Scanner.Parser

  @spec collapse([Parser.parsed()]) :: [Parser.parsed()]
  def collapse(records) do
    records
    |> Enum.reduce(%{}, fn rec, acc ->
      Map.put(acc, {rec.session_id, rec.message_id}, rec)
    end)
    |> Map.values()
  end
end
