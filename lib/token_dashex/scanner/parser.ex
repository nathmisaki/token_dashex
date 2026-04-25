defmodule TokenDashex.Scanner.Parser do
  @moduledoc """
  Pure functions that turn a raw JSONL record (already JSON-decoded) into the
  canonical map shape consumed by `TokenDashex.Ingest`. No I/O, no DB.

  Records of `type` outside of `"user"` / `"assistant"` are skipped — Claude
  Code writes a number of bookkeeping records (attachments, snapshots,
  permission-mode events) that aren't billable messages.
  """

  @type parsed :: %{
          role: String.t(),
          session_id: String.t(),
          message_id: String.t(),
          uuid: String.t() | nil,
          parent_uuid: String.t() | nil,
          project_slug: String.t() | nil,
          cwd: String.t() | nil,
          model: String.t() | nil,
          timestamp: DateTime.t(),
          usage: map(),
          prompt_text: String.t() | nil,
          response_text: String.t() | nil,
          tools: [%{name: String.t(), input_tokens: integer(), output_tokens: integer()}]
        }

  @spec parse_record(map(), String.t() | nil) :: {:ok, parsed} | :skip
  def parse_record(rec, project_slug \\ nil)

  def parse_record(%{"type" => "assistant", "message" => msg} = rec, project_slug) do
    {:ok,
     %{
       role: "assistant",
       session_id: rec["sessionId"],
       message_id: message_id(rec, msg),
       uuid: rec["uuid"],
       parent_uuid: rec["parentUuid"],
       project_slug: project_slug,
       cwd: rec["cwd"],
       model: msg["model"],
       timestamp: parse_ts(rec["timestamp"]),
       usage: usage_map(msg["usage"] || %{}),
       prompt_text: nil,
       response_text: response_text(msg["content"]),
       tools: tools(msg["content"])
     }}
  end

  def parse_record(%{"type" => "user", "message" => msg} = rec, project_slug) do
    {:ok,
     %{
       role: "user",
       session_id: rec["sessionId"],
       message_id: message_id(rec, msg),
       uuid: rec["uuid"],
       parent_uuid: rec["parentUuid"],
       project_slug: project_slug,
       cwd: rec["cwd"],
       model: nil,
       timestamp: parse_ts(rec["timestamp"]),
       usage: %{},
       prompt_text: prompt_text(msg["content"]),
       response_text: nil,
       tools: []
     }}
  end

  def parse_record(_, _), do: :skip

  defp message_id(rec, msg), do: msg["id"] || rec["uuid"]

  defp usage_map(usage) do
    base =
      Map.take(
        usage,
        ~w(input_tokens output_tokens cache_creation_input_tokens cache_read_input_tokens)
      )

    cache = usage["cache_creation"] || %{}
    flat_total = base["cache_creation_input_tokens"] || 0
    ephemeral_5m = cache["ephemeral_5m_input_tokens"]
    ephemeral_1h = cache["ephemeral_1h_input_tokens"] || 0

    # Fall back: older records only publish the flat sum; bucket it as 5m.
    five_m =
      case ephemeral_5m do
        nil -> flat_total - ephemeral_1h
        v -> v
      end

    base
    |> Map.put("cache_creation_5m_input_tokens", max(five_m, 0))
    |> Map.put("cache_creation_1h_input_tokens", ephemeral_1h)
  end

  defp prompt_text(content) when is_binary(content), do: content

  defp prompt_text(content) when is_list(content) do
    content
    |> Enum.filter(&(&1["type"] == "text"))
    |> Enum.map_join("\n", & &1["text"])
    |> nil_if_empty()
  end

  defp prompt_text(_), do: nil

  defp response_text(content) when is_list(content) do
    content
    |> Enum.filter(&(&1["type"] == "text"))
    |> Enum.map_join("\n", & &1["text"])
    |> nil_if_empty()
  end

  defp response_text(_), do: nil

  defp tools(content) when is_list(content) do
    content
    |> Enum.filter(&(&1["type"] == "tool_use"))
    |> Enum.map(fn tu ->
      input_size = tu["input"] |> Jason.encode!() |> byte_size()

      %{
        name: tu["name"] || "unknown",
        input_tokens: div(input_size, 4),
        output_tokens: 0
      }
    end)
  end

  defp tools(_), do: []

  defp nil_if_empty(""), do: nil
  defp nil_if_empty(s), do: s

  defp parse_ts(nil), do: DateTime.utc_now()

  defp parse_ts(iso) when is_binary(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, dt, _} -> dt
      _ -> DateTime.utc_now()
    end
  end
end
