defmodule TokenDashexWeb.SkillsLive do
  use TokenDashexWeb, :live_view

  alias TokenDashex.PubSubTopics
  alias TokenDashex.Skills
  alias TokenDashexWeb.Live.Format

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket),
      do: Phoenix.PubSub.subscribe(TokenDashex.PubSub, PubSubTopics.scanner())

    {:ok, load(socket)}
  end

  @impl true
  def handle_info({:scan_complete, _}, socket), do: {:noreply, load(socket)}

  defp load(socket) do
    socket
    |> assign(:catalog, Skills.catalog())
    |> assign(:usage, Skills.usage_breakdown())
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} active={:skills}>
      <h1 class="text-2xl font-bold">Skills</h1>
      <p class="opacity-70">
        Skills installed under <code>~/.claude/</code> and how often they're invoked.
      </p>

      <Layouts.empty_state :if={@catalog == []} title="No skills installed">
        Place a <code class="badge">SKILL.md</code>
        under <code class="badge">~/.claude/skills/</code>, <code class="badge">~/.claude/scheduled-tasks/</code>,
        or any plugin to populate this list.
      </Layouts.empty_state>

      <div :if={@catalog != []} class="overflow-x-auto card bg-base-200 shadow">
        <table class="table">
          <thead>
            <tr>
              <th>Slug</th>
              <th>Path</th>
              <th class="text-right">Est. tokens</th>
              <th class="text-right">Invocations</th>
              <th class="text-right">Cumulative tokens</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={entry <- @catalog}>
              <td class="font-mono">{entry.slug}</td>
              <td class="font-mono text-xs opacity-70 max-w-md truncate">{entry.path}</td>
              <td class="text-right">{Format.tokens(entry.est_tokens)}</td>
              <td class="text-right">{invocations(@usage, entry.slug)}</td>
              <td class="text-right">{Format.tokens(cumulative(@usage, entry.slug))}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </Layouts.app>
    """
  end

  defp invocations(usage, slug) do
    case Enum.find(usage, &(&1.slug == slug)) do
      %{invocations: n} -> n
      _ -> 0
    end
  end

  defp cumulative(usage, slug) do
    case Enum.find(usage, &(&1.slug == slug)) do
      %{est_tokens: n} -> n
      _ -> 0
    end
  end
end
