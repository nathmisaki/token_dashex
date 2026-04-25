defmodule TokenDashexWeb.OverviewLiveTest do
  use TokenDashexWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TokenDashex.AnalyticsFixtures

  test "renders headline KPIs and charts with seeded data", %{conn: conn} do
    AnalyticsFixtures.insert_message(
      role: "assistant",
      model: "claude-sonnet-4-6",
      input_tokens: 1_000,
      output_tokens: 500
    )

    {:ok, _view, html} = live(conn, "/")

    assert html =~ "Sessions"
    assert html =~ "Turns"
    assert html =~ "Cache create"
    assert html =~ "Est. cost"
    assert html =~ "Your daily work"
    assert html =~ "Token usage by model"
    assert html =~ "Recent sessions"
    assert html =~ "What do these numbers mean?"
  end

  test "switching range patches URL with ?range=", %{conn: conn} do
    AnalyticsFixtures.insert_message(input_tokens: 1, output_tokens: 1)

    {:ok, view, _html} = live(conn, "/")

    view |> element("button[phx-value-range=\"7d\"]") |> render_click()

    assert_patched(view, "/?range=7d")
  end

  test "subscribes to scanner topic and reloads on broadcast", %{conn: conn} do
    AnalyticsFixtures.insert_message(input_tokens: 1, output_tokens: 1)

    {:ok, view, _html} = live(conn, "/")

    Phoenix.PubSub.broadcast(
      TokenDashex.PubSub,
      TokenDashex.PubSubTopics.scanner(),
      {:scan_complete, %TokenDashex.Scanner.Worker.Summary{}}
    )

    assert render(view) =~ "Your daily work"
  end

  test "renders empty state with no data on all-time range", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/?range=all")
    assert html =~ "No data yet"
    assert html =~ "mix dashex.scan"
  end
end
