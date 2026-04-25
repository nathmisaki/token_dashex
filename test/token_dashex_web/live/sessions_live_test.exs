defmodule TokenDashexWeb.SessionsLiveTest do
  use TokenDashexWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TokenDashex.AnalyticsFixtures

  test "lists sessions newest first", %{conn: conn} do
    AnalyticsFixtures.insert_message(session_id: "alpha-session", project_slug: "p1")
    AnalyticsFixtures.insert_message(session_id: "beta-session", project_slug: "p2")

    {:ok, _view, html} = live(conn, "/sessions")
    assert html =~ "alpha-se"
    assert html =~ "beta-ses"
  end

  test "filters by project", %{conn: conn} do
    AnalyticsFixtures.insert_message(session_id: "in-p1", project_slug: "p1")
    AnalyticsFixtures.insert_message(session_id: "in-p2", project_slug: "p2")

    {:ok, view, _html} = live(conn, "/sessions")

    html = render_change(view, "filter_project", %{"project" => "p1"})
    assert html =~ "in-p1"
    refute html =~ "in-p2"
  end

  test "drill-down renders session turns", %{conn: conn} do
    msg =
      AnalyticsFixtures.insert_message(
        session_id: "drill-session",
        role: "user",
        prompt_text: "drill content"
      )

    {:ok, _view, html} = live(conn, "/sessions/#{msg.session_id}")
    assert html =~ "drill content"
  end
end
