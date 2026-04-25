defmodule TokenDashexWeb.PromptsLive do
  use TokenDashexWeb, :live_view

  alias TokenDashex.Analytics.Prompts
  alias TokenDashex.PubSubTopics
  alias TokenDashexWeb.Live.Format

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket),
      do: Phoenix.PubSub.subscribe(TokenDashex.PubSub, PubSubTopics.scanner())

    {:ok, socket |> assign(:sort, :total) |> load()}
  end

  @impl true
  def handle_info({:scan_complete, _}, socket), do: {:noreply, load(socket)}

  @impl true
  def handle_event("sort", %{"by" => by}, socket) do
    {:noreply, socket |> assign(:sort, String.to_existing_atom(by)) |> load()}
  end

  defp load(socket) do
    rows = Prompts.expensive(%{sort: socket.assigns.sort, limit: 100})
    assign(socket, :rows, rows)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} active={:prompts}>
      <header class="flex items-center justify-between">
        <h1 class="text-2xl font-bold">Most expensive prompts</h1>
        <div class="join">
          <.sort_btn current={@sort} value={:total} label="Total" />
          <.sort_btn current={@sort} value={:input} label="Input" />
          <.sort_btn current={@sort} value={:output} label="Output" />
        </div>
      </header>

      <div class="overflow-x-auto card bg-base-200 shadow">
        <table class="table">
          <thead>
            <tr>
              <th>When</th>
              <th>Project</th>
              <th>Prompt</th>
              <th class="text-right">Input</th>
              <th class="text-right">Output</th>
              <th class="text-right">Total</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr :for={row <- @rows}>
              <td class="whitespace-nowrap text-sm opacity-70">{Format.date(row.timestamp)}</td>
              <td><span class="badge badge-ghost">{row.project_slug}</span></td>
              <td class="max-w-xl truncate">{row.prompt_text}</td>
              <td class="text-right">{Format.tokens(row.input_tokens)}</td>
              <td class="text-right">{Format.tokens(row.output_tokens)}</td>
              <td class="text-right font-semibold">{Format.tokens(row.total_tokens)}</td>
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

  attr :current, :atom, required: true
  attr :value, :atom, required: true
  attr :label, :string, required: true

  defp sort_btn(assigns) do
    ~H"""
    <button
      phx-click="sort"
      phx-value-by={@value}
      class={[
        "btn btn-sm join-item",
        @current == @value && "btn-primary"
      ]}
    >
      {@label}
    </button>
    """
  end
end
