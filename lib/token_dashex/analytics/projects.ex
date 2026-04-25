defmodule TokenDashex.Analytics.Projects do
  @moduledoc """
  Per-project token totals, session counts, and last-activity timestamps.
  """

  import Ecto.Query

  alias TokenDashex.ProjectName
  alias TokenDashex.Repo
  alias TokenDashex.Schema.Message

  @type row :: %{
          project_slug: String.t(),
          project_name: String.t(),
          input: non_neg_integer(),
          output: non_neg_integer(),
          cache_create: non_neg_integer(),
          cache_read: non_neg_integer(),
          sessions: non_neg_integer(),
          turns: non_neg_integer(),
          last_at: DateTime.t() | nil
        }

  @spec summary(keyword()) :: [row]
  def summary(opts \\ []) do
    since = Keyword.get(opts, :since)
    slug_to_cwds = cwds_by_slug()

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
        turns: filter(count(m.id), fragment("? = 'user'", m.role)),
        last_at: max(m.timestamp)
      }
    )
    |> apply_since(since)
    |> Repo.all()
    |> Enum.map(fn row ->
      cwds = Map.get(slug_to_cwds, row.project_slug, [])
      Map.put(row, :project_name, ProjectName.best(cwds, row.project_slug))
    end)
    |> merge_by_project_name()
    |> Enum.sort_by(&(&1.input + &1.output + &1.cache_create), :desc)
  end

  # Different slugs can resolve to the same human-readable project_name
  # (e.g. when the project has been opened from two cwds). Fold those rows
  # together so the overview doesn't list the same project twice.
  defp merge_by_project_name(rows) do
    rows
    |> Enum.group_by(& &1.project_name)
    |> Enum.map(fn {_name, [first | _] = group} ->
      Enum.reduce(
        group,
        %{
          first
          | sessions: 0,
            input: 0,
            output: 0,
            cache_create: 0,
            cache_read: 0,
            turns: 0,
            last_at: nil
        },
        fn r, acc ->
          %{
            acc
            | input: acc.input + r.input,
              output: acc.output + r.output,
              cache_create: acc.cache_create + r.cache_create,
              cache_read: acc.cache_read + r.cache_read,
              sessions: acc.sessions + r.sessions,
              turns: acc.turns + r.turns,
              last_at: max_datetime(acc.last_at, r.last_at)
          }
        end
      )
    end)
  end

  defp max_datetime(nil, b), do: b
  defp max_datetime(a, nil), do: a

  defp max_datetime(a, b) do
    case DateTime.compare(a, b) do
      :lt -> b
      _ -> a
    end
  end

  defp cwds_by_slug do
    from(m in Message,
      where: not is_nil(m.cwd),
      distinct: true,
      select: {m.project_slug, m.cwd}
    )
    |> Repo.all()
    |> Enum.group_by(fn {slug, _} -> slug end, fn {_, cwd} -> cwd end)
  end

  defp apply_since(query, nil), do: query
  defp apply_since(query, %DateTime{} = dt), do: from(m in query, where: m.timestamp >= ^dt)
end
