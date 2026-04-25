defmodule TokenDashexWeb.OverviewLive do
  use TokenDashexWeb, :live_view

  alias TokenDashex.Analytics.{ByModel, Daily, Overview, Projects, Sessions, Tools}
  alias TokenDashex.PubSubTopics
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
    if connected?(socket) do
      Phoenix.PubSub.subscribe(TokenDashex.PubSub, PubSubTopics.scanner())
      Phoenix.PubSub.subscribe(TokenDashex.PubSub, PubSubTopics.plan_changed())
    end

    {:ok, assign(socket, range: range_for(@default_range))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    range = range_for(params["range"])
    {:noreply, socket |> assign(:range, range) |> load()}
  end

  @impl true
  def handle_info({:scan_complete, _summary}, socket), do: {:noreply, load(socket)}
  def handle_info({:plan_changed, _key}, socket), do: {:noreply, load(socket)}

  @impl true
  def handle_event("set_range", %{"range" => key}, socket) do
    {:noreply, push_patch(socket, to: ~p"/?range=#{key}")}
  end

  defp load(socket) do
    range = socket.assigns.range
    since = since_for(range)
    opts = if since, do: [since: since], else: []

    daily = Daily.series(opts)
    window = Overview.window(opts)
    projects = Projects.summary(opts) |> Enum.take(8)
    tools = Tools.breakdown(opts) |> Enum.take(8)
    by_model = ByModel.breakdown(opts)
    sessions = Sessions.recent(%{limit: 10, since: since})

    socket
    |> assign(:totals, window)
    |> assign(:daily, daily)
    |> assign(:projects, projects)
    |> assign(:tools, tools)
    |> assign(:by_model, by_model)
    |> assign(:sessions, sessions)
    |> assign(:daily_billable_chart, daily_billable_option(daily))
    |> assign(:daily_cache_chart, daily_cache_option(daily))
    |> assign(:projects_chart, projects_option(projects))
    |> assign(:model_chart, model_option(by_model))
    |> assign(:tools_chart, tools_option(tools))
  end

  defp range_for(nil), do: range_for(@default_range)

  defp range_for(key) do
    Enum.find(@ranges, &(&1.key == key)) || range_for(@default_range)
  end

  defp since_for(%{days: nil}), do: nil

  defp since_for(%{days: days}) do
    DateTime.add(DateTime.utc_now(), -days * 86_400, :second)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} active={:overview}>
      <Layouts.empty_state :if={@totals.sessions == 0 and @range.key == "all"} title="No data yet">
        Run <code class="badge">mix dashex.scan</code> to ingest your Claude Code
        sessions, or wait — the background scanner picks up new files every 30 seconds.
      </Layouts.empty_state>

      <div :if={@totals.sessions > 0 or @range.key != "all"}>
        <.range_header range={@range} />
        <.kpi_row totals={@totals} />
        <.glossary />

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 mt-4">
          <.chart_card
            title="Your daily work"
            subtitle="Tokens you paid for: what you sent (input), what Claude wrote (output), and what got stored for re-use (cache create)."
            id="ch-daily-billable"
            option={@daily_billable_chart}
          />
          <.chart_card
            title="Daily cache reads"
            subtitle="Cache reads are cheap re-uses of things Claude already saw (like your CLAUDE.md). They cost ~10× less than regular input tokens — high numbers here are a good thing."
            id="ch-daily-cache"
            option={@daily_cache_chart}
          />
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 mt-4">
          <.chart_card title="Tokens by project" id="ch-projects" option={@projects_chart} />
          <.chart_card
            title="Token usage by model"
            subtitle="Share of billable tokens per Claude model."
            id="ch-model"
            option={@model_chart}
          />
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 mt-4">
          <.chart_card title="Top tools (by call count)" id="ch-tools" option={@tools_chart} />
          <.recent_sessions sessions={@sessions} />
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :range, :map, required: true

  defp range_header(assigns) do
    assigns = assign(assigns, :ranges, @ranges)

    ~H"""
    <div class="flex items-center gap-3 mb-4">
      <h2 class="text-lg font-semibold m-0">Overview</h2>
      <span class="opacity-60 text-xs">
        {if @range.days, do: "last #{@range.days} days", else: "all time"}
      </span>
      <div class="grow" />
      <div class="join" role="tablist">
        <button
          :for={r <- @ranges}
          type="button"
          phx-click="set_range"
          phx-value-range={r.key}
          class={[
            "btn btn-sm join-item",
            r.key == @range.key && "btn-primary"
          ]}
        >
          {r.label}
        </button>
      </div>
    </div>
    """
  end

  attr :totals, :map, required: true

  defp kpi_row(assigns) do
    cache_create = assigns.totals.cache_create

    assigns = assign(assigns, :cache_create, cache_create)

    ~H"""
    <div class="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-7 gap-3">
      <.kpi
        label="Sessions"
        full={Format.tokens(@totals.sessions)}
        value={Format.compact(@totals.sessions)}
      />
      <.kpi label="Turns" full={Format.tokens(@totals.turns)} value={Format.compact(@totals.turns)} />
      <.kpi
        label="Input"
        full={Format.tokens(@totals.input) <> " tokens"}
        value={Format.compact(@totals.input)}
      />
      <.kpi
        label="Output"
        full={Format.tokens(@totals.output) <> " tokens"}
        value={Format.compact(@totals.output)}
      />
      <.kpi
        label="Cache read"
        full={Format.tokens(@totals.cache_read) <> " tokens"}
        value={Format.compact(@totals.cache_read)}
      />
      <.kpi
        label="Cache create"
        full={Format.tokens(@cache_create) <> " tokens"}
        value={Format.compact(@cache_create)}
      />
      <.kpi
        label="Est. cost"
        full={Format.usd(@totals.cost)}
        value={Format.usd(@totals.cost)}
        highlight
      />
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :full, :string, required: true
  attr :highlight, :boolean, default: false

  defp kpi(assigns) do
    ~H"""
    <div class={[
      "card bg-base-200 shadow",
      @highlight && "ring-1 ring-primary"
    ]}>
      <div class="card-body p-4">
        <div class="text-[11px] uppercase tracking-wide opacity-60">{@label}</div>
        <div class="text-2xl font-bold mt-1 truncate" title={@full}>{@value}</div>
      </div>
    </div>
    """
  end

  defp glossary(assigns) do
    ~H"""
    <details class="collapse collapse-arrow bg-base-200 mt-4">
      <summary class="collapse-title text-sm font-medium">
        What do these numbers mean? <span class="opacity-60">— click to expand</span>
      </summary>
      <div class="collapse-content text-sm">
        <dl class="grid grid-cols-1 md:grid-cols-2 gap-x-6 gap-y-2">
          <div>
            <dt class="font-semibold">Session</dt>
            <dd class="opacity-80">
              One run of Claude Code (from <code>claude</code>
              to exit). Each session is a single <code>.jsonl</code>
              file.
            </dd>
          </div>
          <div>
            <dt class="font-semibold">Turn</dt>
            <dd class="opacity-80">
              One message you sent to Claude. Each turn triggers a response (possibly with tool calls in between).
            </dd>
          </div>
          <div>
            <dt class="font-semibold">Input tokens</dt>
            <dd class="opacity-80">
              The new text you (and tool results) sent to Claude this turn. Billed at the full input rate.
            </dd>
          </div>
          <div>
            <dt class="font-semibold">Output tokens</dt>
            <dd class="opacity-80">
              The text Claude wrote back. Billed at the highest rate — usually the biggest cost driver per turn.
            </dd>
          </div>
          <div>
            <dt class="font-semibold">Cache read</dt>
            <dd class="opacity-80">
              Tokens Claude re-used from a cache (your CLAUDE.md, previously-read files, the conversation so far). ~10× cheaper than fresh input. High cache-read counts = good cost hygiene.
            </dd>
          </div>
          <div>
            <dt class="font-semibold">Cache create</dt>
            <dd class="opacity-80">
              Writing something into the cache for the first time. One-time cost; pays off on the next turn.
            </dd>
          </div>
          <div>
            <dt class="font-semibold">Billable tokens</dt>
            <dd class="opacity-80">
              Input + Output + Cache create. Cache reads are billed separately (and much cheaper).
            </dd>
          </div>
        </dl>
      </div>
    </details>
    """
  end

  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :id, :string, required: true
  attr :option, :string, required: true

  defp chart_card(assigns) do
    ~H"""
    <section class="card bg-base-200 shadow">
      <div class="card-body">
        <h3 class="card-title text-base">{@title}</h3>
        <p :if={@subtitle} class="text-xs opacity-70 -mt-1 mb-1">{@subtitle}</p>
        <div id={@id} phx-hook="ECharts" data-option={@option} class="h-72" />
      </div>
    </section>
    """
  end

  attr :sessions, :list, required: true

  defp recent_sessions(assigns) do
    ~H"""
    <section class="card bg-base-200 shadow">
      <div class="card-body">
        <h3 class="card-title text-base flex items-center">
          <span>Recent sessions</span>
          <span class="grow" />
          <.link navigate={~p"/sessions"} class="text-xs font-normal opacity-80 hover:opacity-100">
            all →
          </.link>
        </h3>
        <table class="table table-sm">
          <thead>
            <tr>
              <th>started</th>
              <th>project</th>
              <th class="text-right">tokens</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={s <- @sessions}>
              <td class="font-mono text-xs whitespace-nowrap">{Format.date(s.last_at)}</td>
              <td>
                <.link navigate={~p"/sessions/#{s.session_id}"}>{s.project_slug}</.link>
              </td>
              <td class="text-right">{Format.compact(s.input + s.output)}</td>
            </tr>
            <tr :if={@sessions == []}>
              <td colspan="3" class="opacity-60 text-center">no sessions in this range</td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>
    """
  end

  # ---------- chart options (server-side JSON) ----------

  @blue "#4A9EFF"
  @purple "#7C5CFF"
  @green "#3FB68B"
  @orange "#E8A23B"

  defp daily_billable_option(daily) do
    cats = Enum.map(daily, &Date.to_iso8601(&1.date))

    %{
      tooltip: %{trigger: "axis", axisPointer: %{type: "shadow"}},
      legend: %{top: 0, right: 0},
      grid: %{left: 36, right: 12, top: 28, bottom: 28, containLabel: true},
      xAxis: %{type: "category", data: cats},
      yAxis: %{type: "value"},
      series: [
        %{
          name: "input",
          type: "bar",
          stack: "total",
          data: Enum.map(daily, & &1.input),
          itemStyle: %{color: @blue},
          barMaxWidth: 24
        },
        %{
          name: "output",
          type: "bar",
          stack: "total",
          data: Enum.map(daily, & &1.output),
          itemStyle: %{color: @purple},
          barMaxWidth: 24
        },
        %{
          name: "cache create",
          type: "bar",
          stack: "total",
          data: Enum.map(daily, & &1.cache_create),
          itemStyle: %{color: @orange},
          barMaxWidth: 24
        }
      ]
    }
    |> Jason.encode!()
  end

  defp daily_cache_option(daily) do
    cats = Enum.map(daily, &Date.to_iso8601(&1.date))

    %{
      tooltip: %{trigger: "axis", axisPointer: %{type: "shadow"}},
      grid: %{left: 36, right: 12, top: 28, bottom: 28, containLabel: true},
      xAxis: %{type: "category", data: cats},
      yAxis: %{type: "value"},
      series: [
        %{
          name: "cache read",
          type: "bar",
          data: Enum.map(daily, & &1.cache_read),
          itemStyle: %{color: @green},
          barMaxWidth: 24
        }
      ]
    }
    |> Jason.encode!()
  end

  defp projects_option(projects) do
    cats =
      Enum.map(projects, fn p ->
        slug = p.project_slug || ""
        if String.length(slug) > 20, do: String.slice(slug, 0, 19) <> "…", else: slug
      end)

    %{
      tooltip: %{trigger: "axis", axisPointer: %{type: "shadow"}},
      legend: %{top: 0, right: 0},
      grid: %{left: 36, right: 12, top: 28, bottom: 40, containLabel: true},
      xAxis: %{type: "category", data: cats, axisLabel: %{rotate: 25, interval: 0}},
      yAxis: %{type: "value"},
      series: [
        %{
          name: "input",
          type: "bar",
          data: Enum.map(projects, & &1.input),
          itemStyle: %{color: @blue, borderRadius: [4, 4, 0, 0]},
          barMaxWidth: 24
        },
        %{
          name: "output",
          type: "bar",
          data: Enum.map(projects, & &1.output),
          itemStyle: %{color: @purple, borderRadius: [4, 4, 0, 0]},
          barMaxWidth: 24
        }
      ]
    }
    |> Jason.encode!()
  end

  defp model_option(by_model) do
    data =
      by_model
      |> Enum.map(fn m ->
        value = (m.input || 0) + (m.output || 0) + (m.cache_create || 0)
        %{name: Format.model_short(m.model), value: value}
      end)
      |> Enum.filter(&(&1.value > 0))

    %{
      tooltip: %{trigger: "item"},
      legend: %{bottom: 10, type: "scroll"},
      series: [
        %{
          type: "pie",
          center: ["50%", "44%"],
          radius: ["48%", "68%"],
          padAngle: 2,
          itemStyle: %{borderColor: "#0F1419", borderWidth: 2, borderRadius: 4},
          label: %{show: true, position: "inside", color: "#fff", fontWeight: 600},
          labelLine: %{show: false},
          data: data
        }
      ]
    }
    |> Jason.encode!()
  end

  defp tools_option(tools) do
    cats = Enum.map(tools, & &1.name)

    %{
      tooltip: %{trigger: "axis", axisPointer: %{type: "shadow"}},
      grid: %{left: 36, right: 12, top: 28, bottom: 40, containLabel: true},
      xAxis: %{type: "category", data: cats, axisLabel: %{rotate: 25, interval: 0}},
      yAxis: %{type: "value"},
      series: [
        %{
          type: "bar",
          data: Enum.map(tools, & &1.invocations),
          itemStyle: %{color: @purple, borderRadius: [4, 4, 0, 0]},
          barMaxWidth: 32
        }
      ]
    }
    |> Jason.encode!()
  end
end
