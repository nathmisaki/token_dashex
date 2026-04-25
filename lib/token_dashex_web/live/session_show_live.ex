defmodule TokenDashexWeb.SessionShowLive do
  use TokenDashexWeb, :live_view

  alias TokenDashex.Analytics.Sessions
  alias TokenDashex.PubSubTopics
  alias TokenDashexWeb.Live.Format

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket),
      do: Phoenix.PubSub.subscribe(TokenDashex.PubSub, PubSubTopics.scanner())

    {:ok,
     socket
     |> assign(:session_id, id)
     |> load()}
  end

  @impl true
  def handle_info({:scan_complete, _}, socket), do: {:noreply, load(socket)}

  defp load(socket) do
    assign(socket, :turns, Sessions.turns(socket.assigns.session_id))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} active={:sessions}>
      <header>
        <.link navigate={~p"/sessions"} class="btn btn-ghost btn-sm mb-2">← Back</.link>
        <h1 class="text-2xl font-bold">Session {Format.short_id(@session_id)}</h1>
      </header>

      <div class="space-y-3">
        <article :for={turn <- @turns} class="card bg-base-200 shadow">
          <div class="card-body">
            <header class="flex items-center justify-between text-sm opacity-70">
              <span class="badge">{turn.role}</span>
              <span>{Format.date(turn.timestamp)}</span>
            </header>

            <p :if={turn.role == "user" and turn.prompt_text} class="whitespace-pre-wrap">
              {turn.prompt_text}
            </p>

            <p :if={turn.role == "assistant" and turn.response_text} class="whitespace-pre-wrap">
              {turn.response_text}
            </p>

            <div :if={turn.role == "assistant"} class="grid grid-cols-4 gap-2 text-xs mt-2">
              <span>Input: {Format.tokens(turn.input_tokens)}</span>
              <span>Output: {Format.tokens(turn.output_tokens)}</span>
              <span>Cache read: {Format.tokens(turn.cache_read_tokens)}</span>
              <span>Cache write: {Format.tokens(turn.cache_creation_tokens)}</span>
            </div>

            <ul :if={turn.tools != []} class="mt-2 space-y-1 text-xs">
              <li :for={tool <- turn.tools} class="badge badge-outline">
                {tool.name}
              </li>
            </ul>
          </div>
        </article>
      </div>
    </Layouts.app>
    """
  end
end
