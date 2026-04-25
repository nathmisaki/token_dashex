defmodule TokenDashexWeb.ProjectsLive do
  use TokenDashexWeb, :live_view

  alias TokenDashex.Analytics.Projects
  alias TokenDashex.PubSubTopics
  alias TokenDashexWeb.Live.Format

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket),
      do: Phoenix.PubSub.subscribe(TokenDashex.PubSub, PubSubTopics.scanner())

    {:ok, load(socket)}
  end

  @impl true
  def handle_info({:scan_complete, _}, socket), do: {:noreply, load(socket)}

  defp load(socket), do: assign(socket, :rows, Projects.summary())

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} active={:projects}>
      <div class="mb-4">
        <h1 class="text-2xl font-bold">Projects</h1>
        <p class="text-sm opacity-60 mt-1">
          Sorted by billable token spend. Cache reads are billed cheaper, so high cache-read columns are good.
        </p>
      </div>

      <Layouts.empty_state :if={@rows == []} title="No projects yet">
        Projects appear once Claude Code records sessions in <code class="badge">~/.claude/projects/</code>.
      </Layouts.empty_state>

      <div :if={@rows != []} class="card bg-base-200 shadow overflow-x-auto">
        <table class="table table-sm w-full">
          <thead>
            <tr>
              <th>PROJECT</th>
              <th class="text-right">SESSIONS</th>
              <th class="text-right">TURNS</th>
              <th class="text-right">BILLABLE TOKENS</th>
              <th class="text-right">CACHE READS</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={row <- @rows} class="hover">
              <td class="font-medium">{row.project_name}</td>
              <td class="text-right">{row.sessions}</td>
              <td class="text-right">{row.turns}</td>
              <td class="text-right">{Format.compact(row.input + row.output + row.cache_create)}</td>
              <td class="text-right">{Format.compact(row.cache_read)}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </Layouts.app>
    """
  end
end
