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
      <h1 class="text-2xl font-bold">Projects</h1>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <article :for={row <- @rows} class="card bg-base-200 shadow">
          <div class="card-body">
            <h2 class="card-title break-all">{row.project_slug}</h2>
            <dl class="grid grid-cols-2 gap-x-2 gap-y-1 text-sm mt-2">
              <dt class="opacity-70">Sessions</dt>
              <dd class="text-right">{row.sessions}</dd>
              <dt class="opacity-70">Input</dt>
              <dd class="text-right">{Format.tokens(row.input)}</dd>
              <dt class="opacity-70">Output</dt>
              <dd class="text-right">{Format.tokens(row.output)}</dd>
              <dt class="opacity-70">Cache read</dt>
              <dd class="text-right">{Format.tokens(row.cache_read)}</dd>
              <dt class="opacity-70">Last activity</dt>
              <dd class="text-right text-xs">{Format.date(row.last_at)}</dd>
            </dl>
          </div>
        </article>
      </div>
    </Layouts.app>
    """
  end
end
