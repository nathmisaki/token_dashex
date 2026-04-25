defmodule TokenDashex.TipsTest do
  use TokenDashex.DataCase, async: false

  alias TokenDashex.AnalyticsFixtures
  alias TokenDashex.Tips
  alias TokenDashex.Schema.Tool

  defmodule AlwaysOn do
    @behaviour TokenDashex.Tips.Rule
    @impl true
    def evaluate, do: [%{key: "always_on", title: "x", body: "y", severity: :info}]
  end

  defmodule NeverOn do
    @behaviour TokenDashex.Tips.Rule
    @impl true
    def evaluate, do: []
  end

  describe "active/1" do
    test "aggregates rules and filters dismissed" do
      tips = Tips.active([AlwaysOn, NeverOn])
      assert [%{key: "always_on"}] = tips

      Tips.dismiss("always_on")
      assert Tips.active([AlwaysOn, NeverOn]) == []
    end
  end

  describe "CacheDiscipline" do
    test "fires per project when cache hit ratio is below 0.4" do
      AnalyticsFixtures.insert_message(
        project_slug: "my-project",
        cache_creation_tokens: 200_000,
        cache_read_tokens: 10_000
      )

      tips = TokenDashex.Tips.CacheDiscipline.evaluate()
      assert [%{key: "cache:" <> _}] = tips
    end

    test "is silent when cache hit ratio is healthy" do
      AnalyticsFixtures.insert_message(
        cache_creation_tokens: 100,
        cache_read_tokens: 1_000
      )

      assert [] = TokenDashex.Tips.CacheDiscipline.evaluate()
    end

    test "is silent when total tokens are below 100k" do
      AnalyticsFixtures.insert_message(
        cache_creation_tokens: 1_000,
        cache_read_tokens: 100
      )

      assert [] = TokenDashex.Tips.CacheDiscipline.evaluate()
    end
  end

  describe "RepeatedReads" do
    test "fires one tip per offending file target" do
      msg = AnalyticsFixtures.insert_message(session_id: "rr1")

      for _ <- 1..11 do
        Repo.insert!(%Tool{
          message_id: msg.id,
          session_id: msg.session_id,
          name: "Read",
          target: "/some/file.ex",
          input_tokens: 1
        })
      end

      tips = TokenDashex.Tips.RepeatedReads.evaluate()
      assert [%{key: "repeat-file:/some/file.ex"}] = tips
    end

    test "produces multiple tips for multiple offending files" do
      msg = AnalyticsFixtures.insert_message(session_id: "rr_a")

      for target <- ["/a/foo.ex", "/b/bar.ex"] do
        for _ <- 1..11 do
          Repo.insert!(%Tool{
            message_id: msg.id,
            session_id: msg.session_id,
            name: "Read",
            target: target,
            input_tokens: 1
          })
        end
      end

      tips = TokenDashex.Tips.RepeatedReads.evaluate()
      assert length(tips) == 2
    end

    test "is silent when reads are below threshold" do
      msg = AnalyticsFixtures.insert_message(session_id: "rr_low")

      for _ <- 1..5 do
        Repo.insert!(%Tool{
          message_id: msg.id,
          session_id: msg.session_id,
          name: "Read",
          target: "/some/file.ex",
          input_tokens: 1
        })
      end

      assert [] = TokenDashex.Tips.RepeatedReads.evaluate()
    end
  end

  describe "OversizedResults" do
    test "fires when tool results over 50k appear 5+ times this week" do
      msg = AnalyticsFixtures.insert_message()

      for _ <- 1..5 do
        Repo.insert!(%Tool{
          message_id: msg.id,
          session_id: msg.session_id,
          name: "_tool_result",
          result_tokens: 60_000
        })
      end

      assert [%{key: "tool-bloat:result-50k+"}] = TokenDashex.Tips.OversizedResults.evaluate()
    end

    test "is silent when fewer than 5 oversized results" do
      msg = AnalyticsFixtures.insert_message()

      for _ <- 1..4 do
        Repo.insert!(%Tool{
          message_id: msg.id,
          session_id: msg.session_id,
          name: "_tool_result",
          result_tokens: 60_000
        })
      end

      assert [] = TokenDashex.Tips.OversizedResults.evaluate()
    end
  end
end
