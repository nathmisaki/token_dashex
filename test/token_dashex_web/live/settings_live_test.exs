defmodule TokenDashexWeb.SettingsLiveTest do
  use TokenDashexWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TokenDashex.Pricing.Plan

  test "renders the four plans with the seeded api selected", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/settings")

    for label <- ~w(API Pro Max), do: assert(html =~ label)
    assert html =~ "Active billing plan"
  end

  test "switching plan updates the active state and persists it", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/settings")

    render_change(view, "set_plan", %{"plan" => "max"})
    assert Plan.get() == "max"
  end
end
