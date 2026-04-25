defmodule TokenDashexWeb.SessionsLive do
  use TokenDashexWeb, :live_view

  alias TokenDashex.Analytics.{Projects, Sessions}
  alias TokenDashex.PubSubTopics
  alias TokenDashexWeb.Live.Format

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket),
      do: Phoenix.PubSub.subscribe(TokenDashex.PubSub, PubSubTopics.scanner())

    {:ok, socket |> assign(:project, nil) |> load()}
  end

  @impl true
  def handle_event("filter_project", %{"project" => p}, socket) do
    project = if p == "", do: nil, else: p
    {:noreply, socket |> assign(:project, project) |> load()}
  end

  @impl true
  def handle_info({:scan_complete, _}, socket), do: {:noreply, load(socket)}

  defp load(socket) do
    socket
    |> assign(:rows, Sessions.recent(%{limit: 100, project_slug: socket.assigns.project}))
    |> assign(:projects, Projects.summary())
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} active={:sessions}>
      <header class="flex items-center justify-between">
        <h1 class="text-2xl font-bold">Recent sessions</h1>
        <form phx-change="filter_project">
          <select name="project" class="select select-bordered select-sm">
            <option value="">All projects</option>
            <option :for={p <- @projects} value={p.project_slug} selected={p.project_slug == @project}>
              {p.project_slug}
            </option>
          </select>
        </form>
      </header>

      <div class="overflow-x-auto card bg-base-200 shadow">
        <table class="table">
          <thead>
            <tr>
              <th>Session</th>
              <th>Project</th>
              <th class="text-right">Turns</th>
              <th class="text-right">Input</th>
              <th class="text-right">Output</th>
              <th>Last activity</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr :for={row <- @rows}>
              <td class="font-mono">{Format.short_id(row.session_id)}</td>
              <td>{row.project_slug}</td>
              <td class="text-right">{row.turns}</td>
              <td class="text-right">{Format.tokens(row.input)}</td>
              <td class="text-right">{Format.tokens(row.output)}</td>
              <td class="whitespace-nowrap text-sm opacity-70">{Format.date(row.last_at)}</td>
              <td>
                <.link
                  navigate={~p"/sessions/#{row.session_id}"}
                  class="btn btn-xs btn-primary"
                >
                  Open
                </.link>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </Layouts.app>
    """
  end
end
