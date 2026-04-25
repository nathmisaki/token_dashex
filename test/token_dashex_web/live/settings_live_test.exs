defmodule TokenDashexWeb.SettingsLiveTest do
  use TokenDashexWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TokenDashex.Pricing.Plan

  test "renders the plan section with the seeded api selected", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/settings")

    for label <- ~w(API Pro Max), do: assert(html =~ label)
    assert html =~ "Plan"
  end

  test "switching plan updates the active state and persists it", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/settings")

    render_submit(view, "save_plan", %{"plan" => "max"})
    assert Plan.get() == "max"
  end
end
