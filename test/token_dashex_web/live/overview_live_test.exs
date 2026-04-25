defmodule TokenDashexWeb.OverviewLiveTest do
  use TokenDashexWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TokenDashex.AnalyticsFixtures

  test "renders headline windows with seeded data", %{conn: conn} do
    AnalyticsFixtures.insert_message(
      role: "assistant",
      model: "claude-sonnet-4-6",
      input_tokens: 1_000,
      output_tokens: 500
    )

    {:ok, _view, html} = live(conn, "/")

    assert html =~ "All time"
    assert html =~ "Today"
    assert html =~ "Last 7 days"
    assert html =~ "Daily token volume"
  end

  test "subscribes to scanner topic and reloads on broadcast", %{conn: conn} do
    AnalyticsFixtures.insert_message(input_tokens: 1, output_tokens: 1)

    {:ok, view, _html} = live(conn, "/")

    Phoenix.PubSub.broadcast(
      TokenDashex.PubSub,
      TokenDashex.PubSubTopics.scanner(),
      {:scan_complete, %TokenDashex.Scanner.Worker.Summary{}}
    )

    assert render(view) =~ "Daily token volume"
  end

  test "renders empty state with no data", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")
    assert html =~ "No data yet"
    assert html =~ "mix dashex.scan"
  end
end
