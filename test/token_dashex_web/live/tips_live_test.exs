defmodule TokenDashexWeb.TipsLiveTest do
  use TokenDashexWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TokenDashex.AnalyticsFixtures

  test "shows the empty state when no tips fire", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/tips")
    assert html =~ "all clear"
  end

  test "renders cache discipline warning and dismiss flow", %{conn: conn} do
    project = "test-project"

    AnalyticsFixtures.insert_message(
      project_slug: project,
      cache_creation_tokens: 200_000,
      cache_read_tokens: 10_000
    )

    {:ok, view, html} = live(conn, "/tips")
    assert html =~ "cache hit rate"

    key = "cache:#{project}"
    html = render_click(view, "dismiss", %{"key" => key})
    refute html =~ "cache hit rate"
  end
end
