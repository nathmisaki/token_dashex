defmodule TokenDashex.Schema.DismissedTipTest do
  use TokenDashex.DataCase, async: false

  alias TokenDashex.Schema.DismissedTip

  test "valid changeset round-trips" do
    {:ok, _} =
      %DismissedTip{}
      |> DismissedTip.changeset(%{key: "cache_discipline", dismissed_at: DateTime.utc_now()})
      |> Repo.insert()

    assert %DismissedTip{key: "cache_discipline"} = Repo.get(DismissedTip, "cache_discipline")
  end

  test "rejects missing fields" do
    changeset = DismissedTip.changeset(%DismissedTip{}, %{})
    refute changeset.valid?

    errors = errors_on(changeset)
    assert Map.has_key?(errors, :key)
    assert Map.has_key?(errors, :dismissed_at)
  end
end
