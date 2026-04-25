defmodule TokenDashexWeb.OverviewLive do
  use TokenDashexWeb, :live_view

  alias TokenDashex.Analytics.{ByModel, Daily, Overview, Projects, Tools}
  alias TokenDashex.PubSubTopics
  alias TokenDashexWeb.Live.Format

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(TokenDashex.PubSub, PubSubTopics.scanner())
      Phoenix.PubSub.subscribe(TokenDashex.PubSub, PubSubTopics.plan_changed())
    end

    {:ok, load(socket)}
  end

  @impl true
  def handle_info({:scan_complete, _summary}, socket), do: {:noreply, load(socket)}
  def handle_info({:plan_changed, _key}, socket), do: {:noreply, load(socket)}

  defp load(socket) do
    daily = Daily.series(30)
    chart_option = build_chart_option(daily)

    socket
    |> assign(:totals, Overview.totals())
    |> assign(:projects, Projects.summary() |> Enum.take(8))
    |> assign(:tools, Tools.breakdown() |> Enum.take(8))
    |> assign(:by_model, ByModel.breakdown())
    |> assign(:chart_option, chart_option)
  end

  defp build_chart_option(rows) do
    dates = Enum.map(rows, &Date.to_iso8601(&1.date))
    inputs = Enum.map(rows, & &1.input)
    outputs = Enum.map(rows, & &1.output)
    cache_reads = Enum.map(rows, & &1.cache_read)

    %{
      tooltip: %{trigger: "axis"},
      legend: %{data: ["input", "output", "cache_read"]},
      grid: %{left: "3%", right: "4%", bottom: "8%", containLabel: true},
      xAxis: %{type: "category", boundaryGap: false, data: dates},
      yAxis: %{type: "value"},
      series: [
        %{name: "input", type: "line", smooth: true, data: inputs},
        %{name: "output", type: "line", smooth: true, data: outputs},
        %{name: "cache_read", type: "line", smooth: true, data: cache_reads}
      ]
    }
    |> Jason.encode!()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} active={:overview}>
      <Layouts.empty_state :if={@totals.all_time.sessions == 0} title="No data yet">
        Run <code class="badge">mix dashex.scan</code> to ingest your Claude Code
        sessions, or wait — the background scanner picks up new files every 30 seconds.
      </Layouts.empty_state>

      <div :if={@totals.all_time.sessions > 0} class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <.window_card label="All time" window={@totals.all_time} />
        <.window_card label="Today" window={@totals.today} />
        <.window_card label="Last 7 days" window={@totals.last_7d} />
      </div>

      <section :if={@totals.all_time.sessions > 0} class="card bg-base-200 shadow">
        <div class="card-body">
          <h2 class="card-title">Daily token volume</h2>
          <div id="overview-chart" phx-hook="ECharts" data-option={@chart_option} class="h-80" />
        </div>
      </section>

      <div :if={@totals.all_time.sessions > 0} class="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <.list_card
          title="Top projects"
          rows={@projects}
          cols={[
            {"Project", & &1.project_slug},
            {"Tokens", &Format.tokens(&1.input + &1.output)},
            {"Sessions", & &1.sessions}
          ]}
        />

        <.list_card
          title="Top tools"
          rows={@tools}
          cols={[
            {"Tool", & &1.name},
            {"Calls", & &1.invocations}
          ]}
        />

        <.list_card
          title="By model"
          rows={@by_model}
          cols={[
            {"Model", & &1.model},
            {"Cost", &Format.usd(&1.cost)}
          ]}
        />
      </div>
    </Layouts.app>
    """
  end

  attr :label, :string, required: true
  attr :window, :map, required: true

  defp window_card(assigns) do
    ~H"""
    <div class="card bg-base-200 shadow">
      <div class="card-body">
        <h3 class="text-sm font-semibold opacity-70">{@label}</h3>
        <div class="text-3xl font-bold">{Format.usd(@window.cost)}</div>
        <dl class="grid grid-cols-2 gap-x-3 gap-y-1 text-sm mt-2">
          <dt class="opacity-70">Input</dt>
          <dd class="text-right">{Format.tokens(@window.input)}</dd>
          <dt class="opacity-70">Output</dt>
          <dd class="text-right">{Format.tokens(@window.output)}</dd>
          <dt class="opacity-70">Cache read</dt>
          <dd class="text-right">{Format.tokens(@window.cache_read)}</dd>
          <dt class="opacity-70">Sessions</dt>
          <dd class="text-right">{@window.sessions}</dd>
        </dl>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :rows, :list, required: true
  attr :cols, :list, required: true

  defp list_card(assigns) do
    ~H"""
    <section class="card bg-base-200 shadow">
      <div class="card-body">
        <h2 class="card-title">{@title}</h2>
        <table class="table table-sm">
          <thead>
            <tr>
              <th :for={{header, _} <- @cols}>{header}</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={row <- @rows}>
              <td :for={{_, fun} <- @cols}>{fun.(row)}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>
    """
  end
end
