defmodule TokenDashexWeb.SkillsLive do
  use TokenDashexWeb, :live_view

  alias TokenDashex.PubSubTopics
  alias TokenDashex.Skills
  alias TokenDashexWeb.Live.Format

  @ranges [
    %{key: "7d", label: "7d", days: 7},
    %{key: "30d", label: "30d", days: 30},
    %{key: "90d", label: "90d", days: 90},
    %{key: "all", label: "All", days: nil}
  ]
  @default_range "30d"

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket),
      do: Phoenix.PubSub.subscribe(TokenDashex.PubSub, PubSubTopics.scanner())

    range = Enum.find(@ranges, &(&1.key == @default_range))
    {:ok, socket |> assign(:range, range) |> load()}
  end

  @impl true
  def handle_event("set_range", %{"range" => key}, socket) do
    range = Enum.find(@ranges, &(&1.key == key)) || socket.assigns.range
    {:noreply, socket |> assign(:range, range) |> load()}
  end

  @impl true
  def handle_info({:scan_complete, _}, socket), do: {:noreply, load(socket)}

  defp load(socket) do
    since = since_for(socket.assigns.range)
    usage = Skills.usage_breakdown(%{since: since})
    active = Enum.filter(usage, &(&1.invocations > 0))

    socket
    |> assign(:usage, usage)
    |> assign(:unique_skills, length(active))
    |> assign(:total_invocations, Enum.sum(Enum.map(active, & &1.invocations)))
    |> assign(:skills_chart, top_skills_chart(active))
  end

  defp since_for(%{days: nil}), do: nil

  defp since_for(%{days: days}),
    do: DateTime.add(DateTime.utc_now(), -days * 86_400, :second)

  defp top_skills_chart([]), do: Jason.encode!(%{})

  defp top_skills_chart(active) do
    top = Enum.take(active, 15)

    %{
      tooltip: %{trigger: "axis", axisPointer: %{type: "shadow"}},
      grid: %{left: 12, right: 12, top: 12, bottom: 60, containLabel: true},
      xAxis: %{
        type: "category",
        data: Enum.map(top, & &1.slug),
        axisLabel: %{rotate: 30, fontSize: 10}
      },
      yAxis: %{type: "value"},
      series: [
        %{
          type: "bar",
          data: Enum.map(top, & &1.invocations),
          itemStyle: %{color: "#3FB68B"},
          barMaxWidth: 40
        }
      ]
    }
    |> Jason.encode!()
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :ranges, @ranges)

    ~H"""
    <Layouts.app flash={@flash} active={:skills}>
      <header class="flex items-center justify-between">
        <h1 class="text-2xl font-bold">
          Skills <span class="text-sm font-normal opacity-60">last {@range.days || "all"} days</span>
        </h1>
        <div class="join" role="tablist">
          <button
            :for={r <- @ranges}
            type="button"
            phx-click="set_range"
            phx-value-range={r.key}
            class={["btn btn-sm join-item", r.key == @range.key && "btn-primary"]}
          >
            {r.label}
          </button>
        </div>
      </header>

      <div class="grid grid-cols-2 gap-4">
        <div class="card bg-base-200 shadow">
          <div class="card-body">
            <div class="text-xs uppercase tracking-wide opacity-60">Unique skills used</div>
            <div class="text-3xl font-bold">{@unique_skills}</div>
          </div>
        </div>
        <div class="card bg-base-200 shadow">
          <div class="card-body">
            <div class="text-xs uppercase tracking-wide opacity-60">Total invocations</div>
            <div class="text-3xl font-bold">{@total_invocations}</div>
          </div>
        </div>
      </div>

      <Layouts.empty_state :if={@unique_skills == 0} title="No skill invocations">
        No skills were invoked in this period. Try widening the time range.
      </Layouts.empty_state>

      <div :if={@unique_skills > 0} class="card bg-base-200 shadow">
        <div class="card-body pb-2">
          <h2 class="card-title text-base">Top skills (by invocations)</h2>
          <div id="ch-skills" phx-hook="ECharts" data-option={@skills_chart} class="h-72" />
        </div>
      </div>

      <div :if={@usage != []} class="overflow-x-auto card bg-base-200 shadow">
        <div class="px-4 pt-4 pb-1 text-sm opacity-70">
          All skills — "Tokens per call" is the size of the skill's
          <code class="badge badge-ghost badge-sm">SKILL.md</code>
          file — what Claude Code loads into context each time the skill is invoked.
        </div>
        <table class="table table-sm">
          <thead>
            <tr>
              <th>Skill</th>
              <th class="text-right">Invocations</th>
              <th class="text-right">Tokens per call</th>
              <th class="text-right">Sessions</th>
              <th>Last used</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={entry <- @usage}>
              <td><code class="badge badge-ghost text-xs">{entry.slug}</code></td>
              <td class="text-right">{entry.invocations}</td>
              <td class="text-right">{Format.tokens(entry.est_tokens)}</td>
              <td class="text-right">{entry.sessions}</td>
              <td class="whitespace-nowrap text-sm opacity-70">{Format.date(entry.last_at)}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </Layouts.app>
    """
  end
end
