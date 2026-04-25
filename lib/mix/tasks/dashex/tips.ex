defmodule Mix.Tasks.Dashex.Tips do
  @moduledoc "Print active tips."
  @shortdoc "Show active tips"

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    case TokenDashex.Tips.active() do
      [] ->
        Mix.shell().info("No tips at the moment — you're all clear.")

      tips ->
        Enum.each(tips, fn tip ->
          Mix.shell().info(IO.ANSI.bright() <> "[#{tip.severity}] #{tip.title}" <> IO.ANSI.reset())
          Mix.shell().info(tip.body)
          Mix.shell().info("")
        end)
    end
  end
end
