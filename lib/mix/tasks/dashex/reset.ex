defmodule Mix.Tasks.Dashex.Reset do
  @moduledoc """
  Wipe ingested Claude Code data so the next scan re-reads every JSONL
  file from scratch.

  Clears the `messages`, `tools`, and `file_states` tables. Keeps app
  settings (`plan`, `dismissed_tips`) and the schema itself — no
  migrations are re-run.

  Flags:
    --scan       also run `mix dashex.scan` after the wipe
    --hard       drop and recreate the database instead of truncating
                 (equivalent to `mix ecto.drop && mix ecto.create &&
                 mix ecto.migrate`)
  """
  @shortdoc "Clear ingested token-dashboard data"

  use Mix.Task
  use Boundary, check: [in: false, out: false]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [scan: :boolean, hard: :boolean])

    if opts[:hard] do
      Mix.Task.run("ecto.drop", ["--quiet"])
      Mix.Task.run("ecto.create", ["--quiet"])
      Mix.Task.run("ecto.migrate", ["--quiet"])
      Mix.shell().info("reset: database dropped and recreated")
    else
      Mix.Task.run("app.start")

      {:ok, _} =
        TokenDashex.Repo.transaction(fn ->
          TokenDashex.Repo.delete_all(TokenDashex.Schema.Tool)
          TokenDashex.Repo.delete_all(TokenDashex.Schema.Message)
          TokenDashex.Repo.delete_all(TokenDashex.Schema.FileState)
        end)

      Mix.shell().info("reset: cleared messages, tools, and file_states")
    end

    if opts[:scan], do: Mix.Task.run("dashex.scan")
  end
end
