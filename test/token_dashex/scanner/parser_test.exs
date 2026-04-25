defmodule TokenDashex.Scanner.ParserTest do
  use ExUnit.Case, async: true

  alias TokenDashex.JsonlFixtures
  alias TokenDashex.Scanner.Parser

  test "parses an assistant record" do
    [_user, assistant | _] = Enum.to_list(JsonlFixtures.stream("simple_session.jsonl"))

    assert {:ok, parsed} = Parser.parse_record(assistant, "demo")

    assert parsed.role == "assistant"
    assert parsed.session_id == "sess_simple"
    assert parsed.message_id == "msg_assist_001"
    assert parsed.project_slug == "demo"
    assert parsed.model == "claude-sonnet-4-6"
    assert parsed.usage["input_tokens"] == 50
    assert parsed.usage["output_tokens"] == 20
    assert parsed.usage["cache_creation_input_tokens"] == 1000
    assert parsed.response_text == "Hi! How can I help?"
    assert parsed.tools == []
  end

  test "parses a user record with string content" do
    [user | _] = Enum.to_list(JsonlFixtures.stream("simple_session.jsonl"))

    assert {:ok, parsed} = Parser.parse_record(user, "demo")
    assert parsed.role == "user"
    assert parsed.message_id == "u-001"
    assert parsed.prompt_text == "hello there"
  end

  test "parses a user record with list content" do
    records = JsonlFixtures.stream("simple_session.jsonl") |> Enum.to_list()
    user_with_list = Enum.at(records, 2)

    assert {:ok, parsed} = Parser.parse_record(user_with_list, "demo")
    assert parsed.role == "user"
    assert parsed.prompt_text == "what is 2+2?"
  end

  test "extracts tools from assistant content" do
    [_, assistant] = Enum.to_list(JsonlFixtures.stream("with_tools.jsonl"))

    assert {:ok, parsed} = Parser.parse_record(assistant, "demo")
    assert [%{name: "Read", input_tokens: tokens}] = parsed.tools
    assert tokens > 0
  end

  test "skips non-message records" do
    assert :skip = Parser.parse_record(%{"type" => "attachment"}, "demo")
    assert :skip = Parser.parse_record(%{"type" => "permission-mode"}, "demo")
  end

  test "tolerates missing timestamp" do
    rec = %{
      "type" => "user",
      "uuid" => "u-x",
      "sessionId" => "s-x",
      "message" => %{"role" => "user", "content" => "hi"}
    }

    assert {:ok, parsed} = Parser.parse_record(rec, nil)
    assert %DateTime{} = parsed.timestamp
  end
end
