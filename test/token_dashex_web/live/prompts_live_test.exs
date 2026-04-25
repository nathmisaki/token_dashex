defmodule TokenDashexWeb.PromptsLiveTest do
  use TokenDashexWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TokenDashex.AnalyticsFixtures

  setup do
    user1 =
      AnalyticsFixtures.insert_message(
        session_id: "shared",
        role: "user",
        uuid: "u1",
        prompt_text: "First prompt body"
      )

    AnalyticsFixtures.insert_message(
      session_id: "shared",
      role: "assistant",
      parent_uuid: user1.uuid,
      input_tokens: 200,
      output_tokens: 800
    )

    user2 =
      AnalyticsFixtures.insert_message(
        session_id: "other",
        role: "user",
        uuid: "u2",
        prompt_text: "Quieter prompt"
      )

    AnalyticsFixtures.insert_message(
      session_id: "other",
      role: "assistant",
      parent_uuid: user2.uuid,
      input_tokens: 5,
      output_tokens: 5
    )

    :ok
  end

  test "renders prompts table sorted by tokens by default", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/prompts")
    assert html =~ "First prompt body"
    assert html =~ "Quieter prompt"
  end

  test "switches sort when clicking most recent button", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/prompts")

    html = render_click(view, "sort", %{"by" => "recent"})
    assert html =~ "First prompt body"
  end
end
