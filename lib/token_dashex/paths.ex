defmodule TokenDashex.Paths do
  @moduledoc """
  Resolves filesystem paths for Claude Code resources consumed by the dashboard.

  All getters honor environment overrides so the dashboard can be pointed at
  alternate roots during development and tests.
  """

  @projects_env "CLAUDE_PROJECTS_DIR"
  @db_env "TOKEN_DASHEX_DB"

  @spec projects_dir() :: String.t()
  def projects_dir do
    System.get_env(@projects_env) || Path.expand("~/.claude/projects")
  end

  @spec db_path() :: String.t()
  def db_path do
    System.get_env(@db_env) || Path.expand("~/.claude/token-dashex.db")
  end

  @spec skills_roots() :: [String.t()]
  def skills_roots do
    [
      Path.expand("~/.claude/skills"),
      Path.expand("~/.claude/scheduled-tasks"),
      Path.expand("~/.claude/plugins")
    ]
  end
end
