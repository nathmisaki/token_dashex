defmodule TokenDashex.Analytics.Sessions do
  @moduledoc """
  Recent session listings + per-session turn drill-downs.
  """

  import Ecto.Query

  alias TokenDashex.Repo
  alias TokenDashex.Schema.{Message, Tool}

  @type session_row :: %{
          session_id: String.t(),
          project_slug: String.t(),
          input: non_neg_integer(),
          output: non_neg_integer(),
          cache_create: non_neg_integer(),
          cache_read: non_neg_integer(),
          first_at: DateTime.t(),
          last_at: DateTime.t(),
          turns: non_neg_integer()
        }

  @spec recent(map()) :: [session_row]
  def recent(opts \\ %{}) do
    limit = Map.get(opts, :limit, 50)
    project = Map.get(opts, :project_slug)
    since = Map.get(opts, :since)

    base =
      from m in Message,
        group_by: [m.session_id, m.project_slug],
        order_by: [desc: max(m.timestamp)],
        select: %{
          session_id: m.session_id,
          project_slug: m.project_slug,
          input: coalesce(sum(m.input_tokens), 0),
          output: coalesce(sum(m.output_tokens), 0),
          cache_create: coalesce(sum(m.cache_creation_tokens), 0),
          cache_read: coalesce(sum(m.cache_read_tokens), 0),
          first_at: min(m.timestamp),
          last_at: max(m.timestamp),
          turns: count(m.id)
        }

    base
    |> filter_project(project)
    |> filter_since(since)
    |> limit(^limit)
    |> Repo.all()
  end

  defp filter_project(query, nil), do: query

  defp filter_project(query, slug),
    do: from(m in query, where: m.project_slug == ^slug)

  defp filter_since(query, nil), do: query

  defp filter_since(query, %DateTime{} = dt),
    do: from(m in query, where: m.timestamp >= ^dt)

  @spec turns(String.t()) :: [Message.t()]
  def turns(session_id) do
    from(m in Message,
      where: m.session_id == ^session_id,
      order_by: [asc: m.timestamp],
      preload: [:tools]
    )
    |> Repo.all()
  end

  @spec tool_calls(String.t()) :: [Tool.t()]
  def tool_calls(session_id) do
    from(t in Tool,
      where: t.session_id == ^session_id,
      order_by: [asc: t.inserted_at]
    )
    |> Repo.all()
  end
end
