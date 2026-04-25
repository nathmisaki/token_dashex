defmodule TokenDashex.PricingTest do
  use ExUnit.Case, async: false

  alias TokenDashex.Pricing

  setup do
    Pricing.reload!()
    :ok
  end

  describe "models/0 and plans/0" do
    test "models include the four canonical Claude models" do
      models = Pricing.models()

      for id <- ~w(claude-opus-4-7 claude-sonnet-4-6 claude-haiku-4-5) do
        assert Map.has_key?(models, id), "expected #{id} in pricing models"
      end
    end

    test "plans expose monthly cost and label" do
      assert %{"monthly" => 200, "label" => "Max 20x"} = Pricing.plan("max-20x")
      assert %{"monthly" => 0} = Pricing.plan("api")
    end
  end

  describe "cost_for/2" do
    test "computes USD using model rates" do
      usage = %{
        "input_tokens" => 1_000_000,
        "output_tokens" => 500_000,
        "cache_creation_input_tokens" => 0,
        "cache_read_input_tokens" => 0
      }

      cost = Pricing.cost_for("claude-sonnet-4-6", usage)
      assert_in_delta cost, 3.00 + 7.50, 0.001
    end

    test "applies cache rates" do
      usage = %{
        "input_tokens" => 0,
        "output_tokens" => 0,
        "cache_creation_input_tokens" => 1_000_000,
        "cache_read_input_tokens" => 1_000_000
      }

      cost = Pricing.cost_for("claude-sonnet-4-6", usage)
      assert_in_delta cost, 3.75 + 0.30, 0.001
    end

    test "falls back to opus tier for unknown opus-like model id" do
      cost = Pricing.cost_for("claude-opus-4-99", %{"input_tokens" => 1_000_000})
      assert_in_delta cost, 15.00, 0.001
    end

    test "returns 0 for nil model with empty usage" do
      assert Pricing.cost_for(nil, %{}) == 0.0
    end

    test "returns 0 for completely unknown model" do
      assert Pricing.cost_for("totally-bogus", %{"input_tokens" => 1_000}) == 0.0
    end
  end
end
