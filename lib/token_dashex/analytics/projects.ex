defmodule TokenDashex.Analytics.Projects do
  @moduledoc """
  Per-project token totals, session counts, and last-activity timestamps.
  """

  import Ecto.Query

  alias TokenDashex.Repo
  alias TokenDashex.Schema.Message

  @type row :: %{
          project_slug: String.t(),
          input: non_neg_integer(),
          output: non_neg_integer(),
          cache_create: non_neg_integer(),
          cache_read: non_neg_integer(),
          sessions: non_neg_integer(),
          last_at: DateTime.t() | nil
        }

  @spec summary() :: [row]
  def summary do
    from(m in Message,
      group_by: m.project_slug,
      order_by: [desc: max(m.timestamp)],
      select: %{
        project_slug: m.project_slug,
        input: coalesce(sum(m.input_tokens), 0),
        output: coalesce(sum(m.output_tokens), 0),
        cache_create: coalesce(sum(m.cache_creation_tokens), 0),
        cache_read: coalesce(sum(m.cache_read_tokens), 0),
        sessions: count(fragment("DISTINCT ?", m.session_id)),
        last_at: max(m.timestamp)
      }
    )
    |> Repo.all()
  end
end
