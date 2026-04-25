defmodule Mix.Tasks.Dashex.Today do
  @moduledoc "Print today's totals for Claude Code usage."
  @shortdoc "Show today's token totals"

  use Mix.Task
  use Boundary, check: [in: false, out: false]

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    %{today: w} = TokenDashex.Analytics.Overview.totals()

    Mix.shell().info("""

    Token Dashex — today
    ────────────────────
    Input tokens : #{w.input}
    Output tokens: #{w.output}
    Sessions     : #{w.sessions}
    Cost         : $#{:erlang.float_to_binary(w.cost, decimals: 2)}
    """)
  end
end
