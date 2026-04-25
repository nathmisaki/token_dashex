defmodule TokenDashex.Skills do
  @moduledoc """
  Discovers and reports on skills installed under the user's `~/.claude/`
  directory tree. A skill is any `SKILL.md` file beneath one of the known
  roots (`skills`, `scheduled-tasks`, `plugins`).

  Plugin-bundled skills follow `<plugin>/skills/<skill>/SKILL.md` and are
  reported with the `"plugin:skill"` slug Claude Code uses elsewhere.
  """

  import Ecto.Query

  alias TokenDashex.{Paths, Repo}
  alias TokenDashex.Schema.Message

  @type entry :: %{slug: String.t(), path: String.t(), est_tokens: non_neg_integer()}

  @spec catalog() :: [entry]
  def catalog do
    Paths.skills_roots()
    |> Enum.flat_map(&scan_root/1)
    |> Enum.uniq_by(& &1.slug)
  end

  @spec usage_breakdown(map()) :: [
          %{
            slug: String.t(),
            invocations: integer(),
            est_tokens: integer(),
            sessions: integer(),
            last_at: DateTime.t() | nil
          }
        ]
  def usage_breakdown(opts \\ %{}) do
    since = Map.get(opts, :since)
    catalog_entries = catalog()

    base =
      from(m in Message,
        where: not is_nil(m.prompt_text) or not is_nil(m.response_text),
        select: %{
          prompt: m.prompt_text,
          response: m.response_text,
          session_id: m.session_id,
          timestamp: m.timestamp
        }
      )

    messages =
      if(since, do: from(m in base, where: m.timestamp >= ^since), else: base)
      |> Repo.all()

    counts = count_invocations(messages, catalog_entries)

    Enum.map(catalog_entries, fn entry ->
      {invocations, session_ids, last_at} = Map.get(counts, entry.slug, {0, MapSet.new(), nil})

      %{
        slug: entry.slug,
        est_tokens: entry.est_tokens,
        invocations: invocations,
        sessions: MapSet.size(session_ids),
        last_at: last_at
      }
    end)
    |> Enum.sort_by(& &1.invocations, :desc)
  end

  defp scan_root(root) do
    if File.dir?(root) do
      root
      |> Path.join("**/SKILL.md")
      |> Path.wildcard()
      |> Enum.map(&entry(&1, root))
    else
      []
    end
  end

  defp entry(path, root) do
    %{slug: slug(path, root), path: path, est_tokens: estimate_tokens(path)}
  end

  defp slug(path, root) do
    rel = Path.relative_to(path, root) |> Path.dirname() |> String.split("/")

    case rel do
      [plugin, "skills", skill_name] -> "#{plugin}:#{skill_name}"
      [single] -> single
      parts -> Enum.join(parts, ":")
    end
  end

  defp estimate_tokens(path) do
    case File.stat(path) do
      {:ok, %File.Stat{size: size}} -> div(size, 4)
      _ -> 0
    end
  end

  defp count_invocations(messages, catalog_entries) do
    slugs = Enum.map(catalog_entries, & &1.slug)

    Enum.reduce(messages, %{}, fn %{prompt: p, response: r, session_id: sid, timestamp: ts},
                                  acc ->
      text = (p || "") <> "\n" <> (r || "")

      Enum.reduce(slugs, acc, fn slug, inner ->
        if String.contains?(text, slug) do
          {inv, sessions, last_at} = Map.get(inner, slug, {0, MapSet.new(), nil})

          new_last =
            if is_nil(last_at) or DateTime.compare(ts, last_at) == :gt, do: ts, else: last_at

          Map.put(inner, slug, {inv + 1, MapSet.put(sessions, sid), new_last})
        else
          inner
        end
      end)
    end)
  end
end
