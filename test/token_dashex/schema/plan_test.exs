defmodule TokenDashex.Schema.PlanTest do
  use TokenDashex.DataCase, async: false

  alias TokenDashex.Schema.Plan

  test "valid_keys lists the four supported plans" do
    assert Plan.valid_keys() == ~w(api pro max max-20x)
  end

  test "rejects unknown plan key" do
    changeset = Plan.changeset(%Plan{}, %{key: "free"})
    refute changeset.valid?
    assert %{key: _} = errors_on(changeset)
  end

  test "defaults id to 1 and stamps updated_at" do
    changeset = Plan.changeset(%Plan{}, %{key: "pro"})
    assert changeset.valid?
    assert Ecto.Changeset.get_field(changeset, :id) == 1
    assert %DateTime{} = Ecto.Changeset.get_field(changeset, :updated_at)
  end

  test "seed row exists after migration" do
    plan = Repo.get(Plan, 1)
    assert %Plan{key: "api"} = plan
  end
end
