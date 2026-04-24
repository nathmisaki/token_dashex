defmodule TokenDashex.PathsTest do
  use ExUnit.Case, async: false

  alias TokenDashex.Paths

  setup do
    on_exit(fn ->
      System.delete_env("CLAUDE_PROJECTS_DIR")
      System.delete_env("TOKEN_DASHEX_DB")
    end)

    :ok
  end

  describe "projects_dir/0" do
    test "honors CLAUDE_PROJECTS_DIR override" do
      System.put_env("CLAUDE_PROJECTS_DIR", "/tmp/jsonl")
      assert Paths.projects_dir() == "/tmp/jsonl"
    end

    test "defaults to ~/.claude/projects" do
      System.delete_env("CLAUDE_PROJECTS_DIR")
      assert Paths.projects_dir() == Path.expand("~/.claude/projects")
    end
  end

  describe "db_path/0" do
    test "honors TOKEN_DASHEX_DB override" do
      System.put_env("TOKEN_DASHEX_DB", "/tmp/x.db")
      assert Paths.db_path() == "/tmp/x.db"
    end

    test "defaults to ~/.claude/token-dashex.db" do
      System.delete_env("TOKEN_DASHEX_DB")
      assert Paths.db_path() == Path.expand("~/.claude/token-dashex.db")
    end
  end

  describe "skills_roots/0" do
    test "returns the three Claude Code skill roots, expanded" do
      paths = Paths.skills_roots()
      assert length(paths) == 3
      assert Enum.all?(paths, &String.starts_with?(&1, "/"))
      assert Enum.any?(paths, &String.ends_with?(&1, "/.claude/skills"))
      assert Enum.any?(paths, &String.ends_with?(&1, "/.claude/scheduled-tasks"))
      assert Enum.any?(paths, &String.ends_with?(&1, "/.claude/plugins"))
    end
  end
end
