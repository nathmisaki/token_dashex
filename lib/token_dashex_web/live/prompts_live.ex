defmodule TokenDashexWeb.PromptsLive do
  use TokenDashexWeb, :live_view

  alias TokenDashex.Analytics.Prompts
  alias TokenDashex.PubSubTopics
  alias TokenDashexWeb.Live.Format

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket),
      do: Phoenix.PubSub.subscribe(TokenDashex.PubSub, PubSubTopics.scanner())

    {:ok, socket |> assign(:sort, :tokens) |> assign(:selected, nil) |> load()}
  end

  @impl true
  def handle_info({:scan_complete, _}, socket), do: {:noreply, load(socket)}

  @impl true
  def handle_event("sort", %{"by" => by}, socket) do
    {:noreply,
     socket |> assign(:sort, String.to_existing_atom(by)) |> assign(:selected, nil) |> load()}
  end

  @impl true
  def handle_event("select", %{"index" => idx}, socket) do
    i = String.to_integer(idx)
    selected = Enum.at(socket.assigns.rows, i)
    {:noreply, assign(socket, :selected, selected)}
  end

  @impl true
  def handle_event("close", _params, socket) do
    {:noreply, assign(socket, :selected, nil)}
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
        <h1 class="text-2xl font-bold">Prompts</h1>
        <div class="join">
          <.sort_btn current={@sort} value={:tokens} label="Most tokens" />
          <.sort_btn current={@sort} value={:recent} label="Most recent" />
        </div>
      </header>

      <p class="text-sm opacity-60">
        <%= if @sort == :recent do %>
          Your latest prompts and the assistant turn each one triggered. Click a row to see the full prompt.
        <% else %>
          The prompts that cost the most tokens. Click a row to see the full prompt.
        <% end %>
      </p>

      <Layouts.empty_state :if={@rows == []} title="No prompts yet">
        Once your sessions are ingested, the most expensive prompts show up here.
      </Layouts.empty_state>

      <div :if={@rows != []} class="overflow-x-auto card bg-base-200 shadow">
        <table class="table">
          <thead>
            <tr>
              <th>{if @sort == :recent, do: "when", else: "cache cost"}</th>
              <th>prompt</th>
              <th>model</th>
              <th class="text-right">tokens</th>
              <th class="text-right">cache rd</th>
              <th>session</th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={{row, i} <- Enum.with_index(@rows)}
              phx-click="select"
              phx-value-index={i}
              class="cursor-pointer hover:bg-base-300"
            >
              <td class="whitespace-nowrap font-mono text-sm opacity-70">
                <%= if @sort == :recent do %>
                  {Format.date(row.timestamp)}
                <% else %>
                  {Format.usd4(row.estimated_cost_usd)}
                <% end %>
              </td>
              <td class="max-w-xl truncate">{row.prompt_text}</td>
              <td>
                <span :if={row.model} class={"badge #{model_badge_class(row.model)}"}>
                  {Format.model_short(row.model)}
                </span>
              </td>
              <td class="text-right font-mono">{Format.tokens(row.billable_tokens)}</td>
              <td class="text-right font-mono opacity-70">{Format.tokens(row.cache_read_tokens)}</td>
              <td>
                <.link
                  navigate={~p"/sessions/#{row.session_id}"}
                  class="link link-primary font-mono text-xs"
                >
                  {Format.short_id(row.session_id)}…
                </.link>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div
        :if={@selected}
        id="prompt-drawer"
        phx-hook="ScrollIntoView"
        class="card bg-base-200 shadow"
      >
        <div class="card-body">
          <div class="flex items-center justify-between">
            <h3 class="card-title text-base">Prompt detail</h3>
            <div class="flex items-center gap-3">
              <span :if={@selected.model} class={"badge #{model_badge_class(@selected.model)}"}>
                {Format.model_short(@selected.model)}
              </span>
              <button phx-click="close" class="btn btn-xs btn-ghost">✕</button>
            </div>
          </div>
          <pre class="whitespace-pre-wrap break-words text-sm bg-base-300 rounded-box p-4 overflow-x-auto">{@selected.prompt_text}</pre>
          <div class="flex flex-wrap gap-4 text-sm opacity-70">
            <span>{Format.date(@selected.timestamp)}</span>
            <span>
              {Format.tokens(@selected.billable_tokens)} billable · {Format.tokens(
                @selected.cache_read_tokens
              )} cache rd · ~{Format.usd4(@selected.estimated_cost_usd)}
            </span>
            <span class="flex-1"></span>
            <.link navigate={~p"/sessions/#{@selected.session_id}"} class="link link-primary">
              Open session →
            </.link>
          </div>
        </div>
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

  defp model_badge_class(model) when is_binary(model) do
    cond do
      String.contains?(model, "opus") -> "badge-error"
      String.contains?(model, "sonnet") -> "badge-warning"
      String.contains?(model, "haiku") -> "badge-success"
      true -> "badge-ghost"
    end
  end

  defp model_badge_class(_), do: "badge-ghost"
end
