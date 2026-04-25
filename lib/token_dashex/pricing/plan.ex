defmodule TokenDashex.Pricing.Plan do
  @moduledoc """
  Persistence + PubSub broadcasting for the user's active billing plan.

  Storage is a single-row `plan` table seeded with `"api"` by migration. On
  every `set/1` we broadcast `{:plan_changed, key}` on `PubSubTopics.plan_changed/0`
  so subscribed LiveViews can re-render with the updated cost basis.
  """

  alias TokenDashex.Repo
  alias TokenDashex.Schema.Plan

  @doc """
  Returns the active plan key. Defaults to `"api"` if no row exists yet.
  """
  @spec get() :: String.t()
  def get do
    case Repo.get(Plan, 1) do
      %Plan{key: key} -> key
      nil -> "api"
    end
  end

  @doc """
  Persists `key` as the active plan and broadcasts the change. Raises if the
  key is not one of `Plan.valid_keys/0`.
  """
  @spec set(String.t()) :: :ok
  def set(key) do
    unless key in Plan.valid_keys() do
      raise ArgumentError, "invalid plan key: #{inspect(key)}"
    end

    plan = Repo.get(Plan, 1) || %Plan{id: 1}

    plan
    |> Plan.changeset(%{key: key, updated_at: DateTime.utc_now()})
    |> Repo.insert_or_update!()

    Phoenix.PubSub.broadcast(
      TokenDashex.PubSub,
      "plan:changed",
      {:plan_changed, key}
    )

    :ok
  end
end
