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
  def handle_event("save_plan", %{"plan" => key}, socket) do
    PlanRow.set(key)
    {:noreply, put_flash(socket, :info, "Plan saved.")}
  end

  @impl true
  def handle_info({:plan_changed, _key}, socket), do: {:noreply, load(socket)}

  defp load(socket) do
    socket
    |> assign(:active_plan, PlanRow.get())
    |> assign(:plans, Pricing.plans())
    |> assign(:models, Pricing.models())
  end

  defp plan_options(plans) do
    [
      {"api", "API (pay-per-token)"},
      {"pro", "Pro — $20/mo"},
      {"max", "Max — $100/mo"},
      {"max-20x", "Max 20x — $200/mo"}
    ]
    |> Enum.filter(fn {key, _} -> Map.has_key?(plans, key) end)
  end

  defp fmt_rate(nil), do: "—"
  defp fmt_rate(n) when is_number(n) and n == 0, do: "—"

  defp fmt_rate(n) when is_number(n) do
    :erlang.float_to_binary(n / 1, [{:decimals, 2}, :compact])
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} active={:settings}>
      <h1 class="text-2xl font-bold mb-6">Settings</h1>

      <%!-- Plan section --%>
      <section class="card bg-base-200 shadow mb-6">
        <div class="card-body">
          <h2 class="card-title">Plan</h2>
          <p class="opacity-70 mb-4">
            Sets how cost is displayed. API mode shows pay-per-token rates.
            Subscription modes show what you actually pay each month.
          </p>

          <form phx-submit="save_plan" class="flex items-center gap-3">
            <select name="plan" class="select select-bordered w-64">
              <option
                :for={{key, label} <- plan_options(@plans)}
                value={key}
                selected={key == @active_plan}
              >
                {label}
              </option>
            </select>
            <button type="submit" class="btn btn-primary">Save</button>
          </form>
        </div>
      </section>

      <%!-- Pricing table section --%>
      <section class="card bg-base-200 shadow mb-6">
        <div class="card-body">
          <h2 class="card-title">Pricing table</h2>
          <p class="opacity-70 mb-4">
            Edit <code class="font-mono text-sm">pricing.json</code>
            in the project root to change rates. Reload the page after editing.
          </p>

          <div class="overflow-x-auto">
            <table class="table table-sm w-full">
              <thead>
                <tr>
                  <th>MODEL</th>
                  <th>INPUT</th>
                  <th>OUTPUT</th>
                  <th>CACHE READ</th>
                  <th>CACHE CR (5m)</th>
                  <th>CACHE CR (1h)</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={{model, rate} <- Enum.sort(@models)}>
                  <td class="font-mono text-sm">{model}</td>
                  <td>{fmt_rate(rate["input"])}</td>
                  <td>{fmt_rate(rate["output"])}</td>
                  <td>{fmt_rate(rate["cache_read"])}</td>
                  <td>{fmt_rate(rate["cache_create_5m"])}</td>
                  <td>{fmt_rate(rate["cache_create_1h"])}</td>
                </tr>
              </tbody>
            </table>
          </div>
          <p class="text-xs opacity-60 mt-2">Rates per 1M tokens, USD.</p>
        </div>
      </section>

      <%!-- Privacy section --%>
      <section class="card bg-base-200 shadow mb-6">
        <div class="card-body">
          <h2 class="card-title">Privacy</h2>
          <p class="opacity-70">
            Press <kbd class="kbd kbd-sm">Cmd/Ctrl</kbd>
            + <kbd class="kbd kbd-sm">B</kbd>
            anywhere to blur prompt text and other sensitive content for screenshots.
          </p>
        </div>
      </section>
    </Layouts.app>
    """
  end
end
