defmodule TokenDashexWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use TokenDashexWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  attr :active, :atom, default: nil, doc: "the active dashboard tab"

  def app(assigns) do
    ~H"""
    <header class="navbar px-4 sm:px-6 lg:px-8 border-b border-base-300">
      <div class="flex-1">
        <a href={~p"/"} class="flex w-fit items-center gap-2">
          <img src={~p"/images/claude-color.png"} alt="Claude" class="h-7 w-7" />
          <span class="text-lg font-bold">Claude Token Dashboard</span>
        </a>
      </div>
      <nav class="flex-none">
        <ul class="menu menu-horizontal px-1 gap-1">
          <.tab to={~p"/"} label="Overview" active={@active == :overview} />
          <.tab to={~p"/prompts"} label="Prompts" active={@active == :prompts} />
          <.tab to={~p"/sessions"} label="Sessions" active={@active == :sessions} />
          <.tab to={~p"/projects"} label="Projects" active={@active == :projects} />
          <.tab to={~p"/skills"} label="Skills" active={@active == :skills} />
          <.tab to={~p"/tips"} label="Tips" active={@active == :tips} />
          <.tab to={~p"/settings"} label="Settings" active={@active == :settings} />
        </ul>
      </nav>
      <div class="flex-none ml-2">
        <.theme_toggle />
      </div>
    </header>

    <main class="px-4 py-6 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-7xl space-y-6">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  attr :icon, :string, default: "hero-information-circle"
  attr :title, :string, required: true
  slot :inner_block, required: true

  def empty_state(assigns) do
    ~H"""
    <section class="card bg-base-200 shadow">
      <div class="card-body items-center text-center py-16">
        <.icon name={@icon} class="size-12 opacity-40" />
        <h3 class="card-title mt-2">{@title}</h3>
        <div class="opacity-70 max-w-md">
          {render_slot(@inner_block)}
        </div>
      </div>
    </section>
    """
  end

  attr :to, :string, required: true
  attr :label, :string, required: true
  attr :active, :boolean, default: false

  defp tab(assigns) do
    ~H"""
    <li>
      <.link
        navigate={@to}
        class={[
          "rounded-md",
          @active && "bg-primary text-primary-content font-semibold"
        ]}
      >
        {@label}
      </.link>
    </li>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
