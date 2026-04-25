defmodule TokenDashex.Release do
  @moduledoc """
  Tasks invokable from a packaged release without Mix on the path.

  Examples:

      bin/token_dashex eval "TokenDashex.Release.migrate()"
      bin/token_dashex eval "TokenDashex.Release.scan()"
      bin/token_dashex eval "TokenDashex.Release.stats()"
  """
  @app :token_dashex

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def scan do
    {:ok, _} = Application.ensure_all_started(@app)
    summary = TokenDashex.Scanner.Worker.tick()
    IO.puts("scanned #{summary.files} files, #{summary.records} records, #{summary.duration_ms}ms")
  end

  def stats do
    {:ok, _} = Application.ensure_all_started(@app)
    %{all_time: w} = TokenDashex.Analytics.Overview.totals()

    IO.puts("""
    Token Dashex — all-time totals
    Input tokens : #{w.input}
    Output tokens: #{w.output}
    Sessions     : #{w.sessions}
    Cost         : $#{:erlang.float_to_binary(w.cost, decimals: 2)}
    """)
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
