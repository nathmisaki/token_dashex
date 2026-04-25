defmodule TokenDashex.AnalyticsTest do
  use TokenDashex.DataCase, async: false

  alias TokenDashex.Analytics.{ByModel, Daily, Overview, Projects, Prompts, Sessions, Tools}
  alias TokenDashex.AnalyticsFixtures

  setup do
    today = DateTime.utc_now()
    yesterday = DateTime.add(today, -86_400, :second)

    user_msg =
      AnalyticsFixtures.insert_message(
        session_id: "s1",
        role: "user",
        prompt_text: "What is 2+2?",
        project_slug: "alpha",
        timestamp: today
      )

    AnalyticsFixtures.insert_message(
      session_id: "s1",
      role: "assistant",
      model: "claude-sonnet-4-6",
      input_tokens: 100,
      output_tokens: 200,
      cache_creation_tokens: 0,
      cache_read_tokens: 1_000,
      project_slug: "alpha",
      response_text: "4",
      timestamp: today
    )

    AnalyticsFixtures.insert_message(
      session_id: "s2",
      role: "assistant",
      model: "claude-opus-4-7",
      input_tokens: 500,
      output_tokens: 800,
      project_slug: "beta",
      timestamp: yesterday
    )

    tool_owner =
      AnalyticsFixtures.insert_message(
        session_id: "s1",
        role: "assistant",
        model: "claude-sonnet-4-6",
        input_tokens: 1,
        output_tokens: 1,
        project_slug: "alpha",
        response_text: "tool message",
        timestamp: today
      )

    AnalyticsFixtures.insert_tool(tool_owner, name: "Read")
    AnalyticsFixtures.insert_tool(tool_owner, name: "Read")
    AnalyticsFixtures.insert_tool(tool_owner, name: "Edit")

    {:ok, user_msg: user_msg}
  end

  describe "Overview.totals/0" do
    test "computes all-time, today, and last-7-days windows" do
      totals = Overview.totals()

      assert totals.all_time.sessions == 2
      assert totals.all_time.projects == 2
      assert totals.all_time.input == 601
      assert totals.all_time.output == 1_001
      assert is_float(totals.all_time.cost)
      assert totals.today.sessions == 1
      assert totals.last_7d.sessions == 2
    end
  end

  describe "Prompts.expensive/1" do
    test "returns user prompts joined with their session totals" do
      [row | _] = Prompts.expensive(%{limit: 5})
      assert row.prompt_text == "What is 2+2?"
      assert row.input_tokens > 0
    end
  end

  describe "Sessions" do
    test "recent/1 lists sessions newest first" do
      assert [%{session_id: "s1"} | _] = Sessions.recent(%{limit: 10})
    end

    test "turns/1 returns ordered messages with preloaded tools" do
      turns = Sessions.turns("s1")
      assert length(turns) >= 3
      assert Enum.all?(turns, fn t -> is_list(t.tools) end)
    end
  end

  describe "Projects.summary/0" do
    test "groups by project slug" do
      summary = Projects.summary()
      slugs = Enum.map(summary, & &1.project_slug)
      assert "alpha" in slugs
      assert "beta" in slugs
    end
  end

  describe "Tools.breakdown/0" do
    test "counts invocations per tool name" do
      rows = Tools.breakdown()
      read_row = Enum.find(rows, &(&1.name == "Read"))
      assert read_row.invocations == 2
    end
  end

  describe "Daily.series/1" do
    test "returns one row per day with cost" do
      rows = Daily.series(30)
      assert length(rows) >= 1
      assert Enum.all?(rows, &is_float(&1.cost))
    end
  end

  describe "ByModel.breakdown/0" do
    test "splits totals by model and computes cost" do
      rows = ByModel.breakdown()
      models = Enum.map(rows, & &1.model)
      assert "claude-sonnet-4-6" in models
      assert "claude-opus-4-7" in models
      assert Enum.all?(rows, &is_float(&1.cost))
    end
  end
end
