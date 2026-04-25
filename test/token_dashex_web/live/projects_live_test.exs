defmodule TokenDashexWeb.ProjectsLiveTest do
  use TokenDashexWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TokenDashex.AnalyticsFixtures

  test "renders one card per project", %{conn: conn} do
    AnalyticsFixtures.insert_message(session_id: "s_a", project_slug: "alpha")
    AnalyticsFixtures.insert_message(session_id: "s_b", project_slug: "beta")

    {:ok, _view, html} = live(conn, "/projects")
    assert html =~ "alpha"
    assert html =~ "beta"
  end
end
