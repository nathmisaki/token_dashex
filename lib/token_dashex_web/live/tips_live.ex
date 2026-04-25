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
      <h1 class="text-2xl font-bold">Tips</h1>

      <div :if={@tips == []} class="card bg-base-200 shadow">
        <div class="card-body text-center opacity-70">
          You're all clear! No tips at the moment.
        </div>
      </div>

      <div class="space-y-3">
        <article
          :for={tip <- @tips}
          class={[
            "alert",
            tip.severity == :warning && "alert-warning",
            tip.severity == :info && "alert-info"
          ]}
        >
          <div class="flex-1">
            <h3 class="font-semibold">{tip.title}</h3>
            <p class="whitespace-pre-wrap text-sm">{tip.body}</p>
          </div>
          <button
            phx-click="dismiss"
            phx-value-key={tip.key}
            class="btn btn-sm btn-ghost"
          >
            Dismiss
          </button>
        </article>
      </div>
    </Layouts.app>
    """
  end
end
