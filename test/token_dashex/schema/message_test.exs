defmodule TokenDashex.Schema.MessageTest do
  use TokenDashex.DataCase, async: false

  alias TokenDashex.Schema.Message

  @valid_attrs %{
    id: "sess_a:msg_01",
    session_id: "sess_a",
    message_id: "msg_01",
    project_slug: "demo",
    role: "assistant",
    model: "claude-sonnet-4-6",
    input_tokens: 100,
    output_tokens: 200,
    cache_creation_tokens: 0,
    cache_read_tokens: 50,
    prompt_text: nil,
    response_text: "hi",
    timestamp: DateTime.utc_now()
  }

  test "valid changeset with all fields" do
    changeset = Message.changeset(%Message{}, @valid_attrs)
    assert changeset.valid?
  end

  test "rejects missing required fields" do
    changeset = Message.changeset(%Message{}, %{})
    refute changeset.valid?

    errors = errors_on(changeset)

    for field <- [:id, :session_id, :message_id, :project_slug, :role, :timestamp] do
      assert Map.has_key?(errors, field), "expected error on #{field}"
    end
  end

  test "rejects invalid role" do
    attrs = Map.put(@valid_attrs, :role, "ghost")
    changeset = Message.changeset(%Message{}, attrs)
    refute changeset.valid?
    assert %{role: _} = errors_on(changeset)
  end

  test "rejects negative token counts" do
    attrs = Map.put(@valid_attrs, :input_tokens, -1)
    changeset = Message.changeset(%Message{}, attrs)
    refute changeset.valid?
    assert %{input_tokens: _} = errors_on(changeset)
  end

  test "round-trips through the database" do
    {:ok, _} = Repo.insert(Message.changeset(%Message{}, @valid_attrs))
    assert %Message{message_id: "msg_01"} = Repo.get(Message, "sess_a:msg_01")
  end
end
