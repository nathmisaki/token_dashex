defmodule TokenDashex.Schema.ToolTest do
  use TokenDashex.DataCase, async: false

  alias TokenDashex.Schema.{Message, Tool}

  defp insert_message do
    {:ok, msg} =
      %Message{}
      |> Message.changeset(%{
        id: "s:m",
        session_id: "s",
        message_id: "m",
        project_slug: "demo",
        role: "assistant",
        timestamp: DateTime.utc_now()
      })
      |> Repo.insert()

    msg
  end

  test "valid changeset" do
    msg = insert_message()

    changeset =
      Tool.changeset(%Tool{}, %{
        message_id: msg.id,
        session_id: msg.session_id,
        name: "Read",
        input_tokens: 10,
        result_tokens: 4_000
      })

    assert changeset.valid?
  end

  test "rejects missing required fields" do
    changeset = Tool.changeset(%Tool{}, %{})
    refute changeset.valid?

    errors = errors_on(changeset)
    assert Map.has_key?(errors, :message_id)
    assert Map.has_key?(errors, :session_id)
    assert Map.has_key?(errors, :name)
  end

  test "cascades on parent message delete" do
    msg = insert_message()

    {:ok, _} =
      %Tool{}
      |> Tool.changeset(%{message_id: msg.id, session_id: msg.session_id, name: "Read"})
      |> Repo.insert()

    Repo.delete!(msg)
    assert [] = Repo.all(Tool)
  end
end
