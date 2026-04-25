defmodule TokenDashex.Ingest do
  @moduledoc """
  Persists parsed scanner records into the database. Idempotent: re-running
  with the same `(session_id, message_id)` will overwrite the previous row,
  which is exactly what we want for streaming-snapshot replays.
  """

  import Ecto.Query

  alias TokenDashex.Repo
  alias TokenDashex.Schema.{Message, Tool}
  alias TokenDashex.Scanner.Parser

  @spec upsert_records([Parser.parsed()]) :: {:ok, non_neg_integer()}
  def upsert_records(records) when is_list(records) do
    Repo.transaction(fn ->
      Enum.each(records, &upsert/1)
    end)

    {:ok, length(records)}
  end

  defp upsert(rec) do
    msg_id = "#{rec.session_id}:#{rec.message_id}"
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    msg_attrs = %{
      id: msg_id,
      session_id: rec.session_id,
      message_id: rec.message_id,
      uuid: rec[:uuid],
      parent_uuid: rec[:parent_uuid],
      project_slug: rec.project_slug || "_unknown",
      role: rec.role,
      model: rec.model,
      input_tokens: rec.usage["input_tokens"] || 0,
      output_tokens: rec.usage["output_tokens"] || 0,
      cache_creation_tokens: rec.usage["cache_creation_input_tokens"] || 0,
      cache_creation_5m_tokens: rec.usage["cache_creation_5m_input_tokens"] || 0,
      cache_creation_1h_tokens: rec.usage["cache_creation_1h_input_tokens"] || 0,
      cache_read_tokens: rec.usage["cache_read_input_tokens"] || 0,
      prompt_text: rec.prompt_text,
      response_text: rec.response_text,
      cwd: rec[:cwd],
      timestamp: ensure_usec(rec.timestamp)
    }

    Repo.insert_all(Message, [msg_attrs],
      on_conflict: {:replace_all_except, [:id]},
      conflict_target: :id
    )

    Repo.delete_all(from t in Tool, where: t.message_id == ^msg_id)

    if rec.tools != [] do
      tools =
        Enum.map(rec.tools, fn tool ->
          %{
            id: Ecto.UUID.bingenerate(),
            message_id: msg_id,
            session_id: rec.session_id,
            name: tool.name,
            input_tokens: tool.input_tokens,
            output_tokens: tool.output_tokens,
            result_tokens: 0,
            inserted_at: now
          }
        end)

      Repo.insert_all(Tool, tools)
    end
  end

  defp ensure_usec(%DateTime{microsecond: {_, 6}} = dt), do: dt
  defp ensure_usec(%DateTime{} = dt), do: %{dt | microsecond: {0, 6}}
end
