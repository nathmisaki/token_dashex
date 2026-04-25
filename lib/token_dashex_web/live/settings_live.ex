defmodule TokenDashexWeb.SettingsLive do
  use TokenDashexWeb, :live_view

  alias TokenDashex.Pricing
  alias TokenDashex.Pricing.Plan, as: PlanRow
  alias TokenDashex.PubSubTopics

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket),
      do: Phoenix.PubSub.subscribe(TokenDashex.PubSub, PubSubTopics.plan_changed())

    {:ok, load(socket)}
  end

  @impl true
  def handle_event("set_plan", %{"plan" => key}, socket) do
    PlanRow.set(key)
    {:noreply, put_flash(socket, :info, "Active plan: #{key}")}
  end

  @impl true
  def handle_info({:plan_changed, _key}, socket), do: {:noreply, load(socket)}

  defp load(socket) do
    socket
    |> assign(:active_plan, PlanRow.get())
    |> assign(:plans, Pricing.plans())
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} active={:settings}>
      <h1 class="text-2xl font-bold">Settings</h1>

      <section class="card bg-base-200 shadow">
        <div class="card-body">
          <h2 class="card-title">Active billing plan</h2>
          <p class="opacity-70">
            Switching plans recomputes the dashboard cost basis live.
          </p>

          <form phx-change="set_plan" class="space-y-2 mt-4">
            <label
              :for={key <- ~w(api pro max max-20x)}
              class={[
                "flex items-center gap-3 p-3 rounded-lg border",
                key == @active_plan && "border-primary bg-base-300"
              ]}
            >
              <input
                type="radio"
                name="plan"
                value={key}
                checked={key == @active_plan}
                class="radio radio-primary"
              />
              <span class="flex-1 font-semibold">{label_for(@plans, key)}</span>
              <span class="text-sm opacity-70">{monthly_for(@plans, key)}</span>
            </label>
          </form>
        </div>
      </section>
    </Layouts.app>
    """
  end

  defp label_for(plans, key), do: get_in(plans, [key, "label"]) || key

  defp monthly_for(plans, key) do
    case get_in(plans, [key, "monthly"]) do
      0 -> "pay-per-token"
      n when is_number(n) -> "$#{n}/mo"
      _ -> ""
    end
  end
end
