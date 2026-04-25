defmodule Mix.Tasks.Dashex.Scan do
  @moduledoc "Scan ~/.claude/projects JSONL files into the local database."
  @shortdoc "Scan Claude Code JSONL files"

  use Mix.Task
  use Boundary, check: [in: false, out: false]

  @impl Mix.Task
  def run(_args) do
    Application.put_env(:token_dashex, :scanner_auto_tick, false)
    Mix.Task.run("app.start")

    summary = TokenDashex.Scanner.Worker.tick()

    Mix.shell().info(
      "scanned #{summary.files} files, #{summary.records} records, " <>
        "#{summary.duration_ms}ms"
    )
  end
end
