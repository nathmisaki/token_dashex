defmodule TokenDashex.Scanner.Walker do
  @moduledoc """
  Discovers JSONL files under a project root and derives the project slug
  used as the session's display name.

  Slug rules:
    * top-level `<root>/<project>/session.jsonl` → `"project"`
    * nested  `<root>/<project>/sub/session.jsonl` → `"project--sub"`
  This matches Claude Code's own filesystem layout where each project's
  recordings live in `~/.claude/projects/<encoded-cwd>/`.
  """

  @type entry :: {path :: String.t(), project_slug :: String.t()}

  @spec walk(String.t()) :: [entry]
  def walk(root) do
    if File.dir?(root) do
      root
      |> Path.join("**/*.jsonl")
      |> Path.wildcard()
      |> Enum.map(&{&1, project_slug(&1, root)})
    else
      []
    end
  end

  @spec project_slug(String.t(), String.t()) :: String.t()
  def project_slug(path, root) do
    rel = Path.relative_to(path, root)
    dir = Path.dirname(rel)

    case dir do
      "." -> "_root"
      _ -> String.replace(dir, "/", "--")
    end
  end
end
