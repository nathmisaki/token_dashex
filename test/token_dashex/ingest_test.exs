defmodule TokenDashex.IngestTest do
  use TokenDashex.DataCase, async: false

  alias TokenDashex.Ingest
  alias TokenDashex.Schema.{Message, Tool}

  defp record(overrides \\ %{}) do
    Map.merge(
      %{
        role: "assistant",
        session_id: "s1",
        message_id: "m1",
        project_slug: "demo",
        model: "claude-sonnet-4-6",
        timestamp: DateTime.utc_now(),
        usage: %{
          "input_tokens" => 100,
          "output_tokens" => 50,
          "cache_creation_input_tokens" => 200,
          "cache_read_input_tokens" => 300
        },
        prompt_text: nil,
        response_text: "hi",
        tools: []
      },
      overrides
    )
  end

  test "inserts message row keyed by session:msg" do
    {:ok, 1} = Ingest.upsert_records([record()])

    assert %Message{
             input_tokens: 100,
             output_tokens: 50,
             cache_creation_tokens: 200,
             cache_read_tokens: 300
           } = Repo.get(Message, "s1:m1")
  end

  test "is idempotent — re-ingest replaces token counts" do
    {:ok, 1} = Ingest.upsert_records([record()])
    {:ok, 1} = Ingest.upsert_records([record(%{usage: %{"output_tokens" => 999}})])

    assert %Message{output_tokens: 999, input_tokens: 0} = Repo.get(Message, "s1:m1")
  end

  test "inserts tools alongside the message" do
    rec = record(%{tools: [%{name: "Read", input_tokens: 4, output_tokens: 0}]})
    {:ok, 1} = Ingest.upsert_records([rec])

    assert [%Tool{name: "Read"}] = Repo.all(Tool)
  end

  test "replaces tools when message is re-ingested" do
    rec1 = record(%{tools: [%{name: "Read", input_tokens: 4, output_tokens: 0}]})
    rec2 = record(%{tools: [%{name: "Edit", input_tokens: 8, output_tokens: 0}]})

    {:ok, _} = Ingest.upsert_records([rec1])
    {:ok, _} = Ingest.upsert_records([rec2])

    assert [%Tool{name: "Edit"}] = Repo.all(Tool)
  end
end
