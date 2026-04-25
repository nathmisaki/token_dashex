defmodule TokenDashex.Pricing.PlanTest do
  use TokenDashex.DataCase, async: false

  alias TokenDashex.Pricing.Plan

  test "get/0 returns the seeded 'api' plan after migration" do
    assert Plan.get() == "api"
  end

  test "set/1 persists and round-trips" do
    assert :ok = Plan.set("max")
    assert Plan.get() == "max"
  end

  test "set/1 broadcasts {:plan_changed, key}" do
    Phoenix.PubSub.subscribe(TokenDashex.PubSub, "plan:changed")
    Plan.set("pro")
    assert_receive {:plan_changed, "pro"}
  end

  test "set/1 rejects unknown keys" do
    assert_raise ArgumentError, fn -> Plan.set("free") end
  end
end
