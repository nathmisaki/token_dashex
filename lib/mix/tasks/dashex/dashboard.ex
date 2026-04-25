defmodule Mix.Tasks.Dashex.Dashboard do
  @moduledoc """
  Scan the JSONL corpus, start the Phoenix endpoint, and open the dashboard
  in the default browser.

  Flags:
    --no-scan   skip the initial scan
    --no-open   don't open the browser
  """

  @shortdoc "Run scan, then start the dashboard"

  use Mix.Task
  use Boundary, check: [in: false, out: false]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: [scan: :boolean, open: :boolean])

    Application.put_env(:token_dashex, :scanner_auto_tick, false)
    Application.put_env(:token_dashex, TokenDashexWeb.Endpoint, server: true, force_init: true)

    Mix.Task.run("app.start")

    if Keyword.get(opts, :scan, true) do
      Mix.Task.run("dashex.scan")
    end

    url = "http://127.0.0.1:#{port()}"
    Mix.shell().info("\nDashboard ready at #{url}\n")

    if Keyword.get(opts, :open, true) do
      open_in_browser(url)
    end

    Process.sleep(:infinity)
  end

  defp port do
    System.get_env("PORT") || "8081"
  end

  defp open_in_browser(url) do
    cmd =
      case :os.type() do
        {:unix, :darwin} -> ["open", url]
        {:unix, _} -> ["xdg-open", url]
        {:win32, _} -> ["cmd", "/c", "start", url]
      end

    [bin | rest] = cmd
    System.cmd(bin, rest, stderr_to_stdout: true)
  rescue
    _ -> :ok
  end
end
