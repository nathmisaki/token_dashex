defmodule TokenDashex.AnalyticsFixtures do
  @moduledoc false

  alias TokenDashex.Repo
  alias TokenDashex.Schema.{Message, Tool}

  def insert_message(attrs) do
    defaults = %{
      session_id: "s1",
      message_id: "m_#{:erlang.unique_integer([:positive])}",
      project_slug: "demo",
      role: "assistant",
      model: "claude-sonnet-4-6",
      input_tokens: 0,
      output_tokens: 0,
      cache_creation_tokens: 0,
      cache_read_tokens: 0,
      prompt_text: nil,
      response_text: nil,
      timestamp: DateTime.utc_now()
    }

    merged = Map.merge(defaults, Enum.into(attrs, %{}))
    id = "#{merged.session_id}:#{merged.message_id}"

    %Message{}
    |> Message.changeset(Map.put(merged, :id, id))
    |> Repo.insert!()
  end

  def insert_tool(message, attrs \\ []) do
    defaults = %{
      session_id: message.session_id,
      message_id: message.id,
      name: "Read",
      input_tokens: 5,
      output_tokens: 0,
      result_tokens: 1_000
    }

    %Tool{}
    |> Tool.changeset(Map.merge(defaults, Enum.into(attrs, %{})))
    |> Repo.insert!()
  end
end
