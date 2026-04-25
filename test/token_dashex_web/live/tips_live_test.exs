defmodule TokenDashexWeb.TipsLiveTest do
  use TokenDashexWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TokenDashex.AnalyticsFixtures

  test "shows the empty state when no tips fire", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/tips")
    assert html =~ "all clear"
  end

  test "renders cache discipline warning and dismiss flow", %{conn: conn} do
    AnalyticsFixtures.insert_message(
      cache_creation_tokens: 1_000,
      cache_read_tokens: 100
    )

    {:ok, view, html} = live(conn, "/tips")
    assert html =~ "Cache hit rate"

    html = render_click(view, "dismiss", %{"key" => "cache_discipline"})
    refute html =~ "Cache hit rate"
  end
end
