defmodule Mix.Tasks.Dashex.Stats do
  @moduledoc "Print all-time totals for Claude Code usage."
  @shortdoc "Show all-time token totals"

  use Mix.Task
  use Boundary, check: [in: false, out: false]

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    %{all_time: w} = TokenDashex.Analytics.Overview.totals()

    Mix.shell().info("""

    Token Dashex — all-time totals
    ──────────────────────────────
    Input tokens : #{format(w.input)}
    Output tokens: #{format(w.output)}
    Cache reads  : #{format(w.cache_read)}
    Cache writes : #{format(w.cache_create)}
    Sessions     : #{w.sessions}
    Projects     : #{w.projects}
    Cost         : $#{:erlang.float_to_binary(w.cost, decimals: 2)}
    """)
  end

  defp format(n) do
    n
    |> Integer.to_charlist()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.intersperse(?,)
    |> List.flatten()
    |> Enum.reverse()
    |> List.to_string()
  end
end
