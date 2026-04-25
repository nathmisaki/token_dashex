defmodule TokenDashexWeb.Router do
  use TokenDashexWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TokenDashexWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", TokenDashexWeb do
    pipe_through :browser

    live "/", OverviewLive, :index
    live "/prompts", PromptsLive, :index
    live "/sessions", SessionsLive, :index
    live "/sessions/:id", SessionShowLive, :show
    live "/projects", ProjectsLive, :index
    live "/skills", SkillsLive, :index
    live "/tips", TipsLive, :index
    live "/settings", SettingsLive, :index
  end

  if Application.compile_env(:token_dashex, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TokenDashexWeb.Telemetry
    end
  end
end
