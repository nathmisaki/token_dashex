defmodule TokenDashexWeb.TipsLive do
  use TokenDashexWeb, :live_view

  alias TokenDashex.PubSubTopics
  alias TokenDashex.Tips

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(TokenDashex.PubSub, PubSubTopics.scanner())
      Phoenix.PubSub.subscribe(TokenDashex.PubSub, PubSubTopics.tips_changed())
    end

    {:ok, load(socket)}
  end

  @impl true
  def handle_event("dismiss", %{"key" => key}, socket) do
    Tips.dismiss(key)
    {:noreply, load(socket)}
  end

  @impl true
  def handle_info({:scan_complete, _}, socket), do: {:noreply, load(socket)}
  def handle_info(:tips_changed, socket), do: {:noreply, load(socket)}

  defp load(socket), do: assign(socket, :tips, Tips.active())

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} active={:tips}>
      <section class="card bg-base-200 shadow">
        <div class="card-body">
          <div>
            <h2 class="card-title">Suggestions</h2>
            <p class="text-sm opacity-70 mt-1">
              Rule-based pattern detection over the last 7 days. Dismissed tips re-appear after 14 days.
            </p>
          </div>

          <div :if={@tips == []} class="text-sm opacity-70 mt-2">
            You're all clear! No tips at the moment.
          </div>

          <div class="space-y-2 mt-2">
            <.tip_card :for={tip <- @tips} tip={tip} />
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end

  attr :tip, :map, required: true

  defp tip_card(assigns) do
    ~H"""
    <article class="card bg-base-100 border border-base-300">
      <div class="card-body p-4 flex-row items-start gap-4">
        <div class="flex-1 min-w-0">
          <div class="flex items-baseline gap-2 flex-wrap">
            <span class="badge badge-sm font-mono text-xs">{@tip[:category] || "tip"}</span>
            <h3 class="font-semibold break-words">{@tip.title}</h3>
          </div>
          <p class="whitespace-pre-wrap text-sm opacity-80 mt-1">{@tip.body}</p>
        </div>
        <button
          phx-click="dismiss"
          phx-value-key={@tip.key}
          class="btn btn-sm btn-ghost font-mono"
        >
          dismiss
        </button>
      </div>
    </article>
    """
  end
end
