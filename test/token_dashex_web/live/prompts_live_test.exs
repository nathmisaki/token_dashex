defmodule TokenDashexWeb.PromptsLiveTest do
  use TokenDashexWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TokenDashex.AnalyticsFixtures

  setup do
    AnalyticsFixtures.insert_message(
      session_id: "shared",
      role: "user",
      prompt_text: "First prompt body"
    )

    AnalyticsFixtures.insert_message(
      session_id: "shared",
      role: "assistant",
      input_tokens: 200,
      output_tokens: 800
    )

    AnalyticsFixtures.insert_message(
      session_id: "other",
      role: "user",
      prompt_text: "Quieter prompt"
    )

    AnalyticsFixtures.insert_message(
      session_id: "other",
      role: "assistant",
      input_tokens: 5,
      output_tokens: 5
    )

    :ok
  end

  test "renders prompts table sorted by total by default", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/prompts")
    assert html =~ "First prompt body"
    assert html =~ "Quieter prompt"
  end

  test "switches sort when clicking the input button", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/prompts")

    html = render_click(view, "sort", %{"by" => "input"})
    assert html =~ "First prompt body"
  end
end
