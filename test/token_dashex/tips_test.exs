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
    test "fires when cache hit ratio is below 0.5" do
      AnalyticsFixtures.insert_message(
        cache_creation_tokens: 1_000,
        cache_read_tokens: 100
      )

      tips = TokenDashex.Tips.CacheDiscipline.evaluate()
      assert [%{key: "cache_discipline"}] = tips
    end

    test "is silent when cache hit ratio is healthy" do
      AnalyticsFixtures.insert_message(
        cache_creation_tokens: 100,
        cache_read_tokens: 1_000
      )

      assert [] = TokenDashex.Tips.CacheDiscipline.evaluate()
    end
  end

  describe "RepeatedReads" do
    test "fires when more than five Reads in a session" do
      msg = AnalyticsFixtures.insert_message(session_id: "rr1")

      for _ <- 1..6 do
        Repo.insert!(%Tool{
          message_id: msg.id,
          session_id: msg.session_id,
          name: "Read",
          input_tokens: 1
        })
      end

      assert [%{key: "repeated_reads"}] = TokenDashex.Tips.RepeatedReads.evaluate()
    end
  end

  describe "OversizedResults" do
    test "fires when a tool returns >50k tokens" do
      msg = AnalyticsFixtures.insert_message()

      Repo.insert!(%Tool{
        message_id: msg.id,
        session_id: msg.session_id,
        name: "Read",
        result_tokens: 60_000
      })

      assert [%{key: "oversized_results"}] = TokenDashex.Tips.OversizedResults.evaluate()
    end
  end
end
