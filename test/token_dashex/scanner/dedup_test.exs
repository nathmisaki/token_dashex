defmodule TokenDashex.Scanner.DedupTest do
  use ExUnit.Case, async: true

  alias TokenDashex.Scanner.Dedup

  defp rec(session_id, message_id, output_tokens) do
    %{
      session_id: session_id,
      message_id: message_id,
      role: "assistant",
      usage: %{"output_tokens" => output_tokens}
    }
  end

  test "collapses duplicate (session_id, message_id) keeping the last" do
    records = [
      rec("s1", "m1", 1),
      rec("s1", "m1", 5),
      rec("s1", "m1", 10)
    ]

    assert [%{usage: %{"output_tokens" => 10}}] = Dedup.collapse(records)
  end

  test "preserves distinct messages within the same session" do
    records = [rec("s1", "m1", 5), rec("s1", "m2", 8)]

    collapsed = Dedup.collapse(records)
    assert length(collapsed) == 2
  end

  test "preserves messages with the same id across different sessions" do
    records = [rec("s1", "m1", 5), rec("s2", "m1", 9)]

    collapsed = Dedup.collapse(records)
    assert length(collapsed) == 2
  end

  test "empty input yields empty output" do
    assert Dedup.collapse([]) == []
  end
end
