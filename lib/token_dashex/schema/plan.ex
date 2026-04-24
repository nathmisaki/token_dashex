defmodule TokenDashex.Schema.Plan do
  @moduledoc """
  Single-row table holding the active billing plan key.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :integer, autogenerate: false}

  schema "plan" do
    field :key, :string
    field :updated_at, :utc_datetime_usec
  end

  @valid_keys ~w(api pro max max-20x)

  def valid_keys, do: @valid_keys

  def changeset(struct, params) do
    struct
    |> cast(params, [:id, :key, :updated_at])
    |> validate_required([:key])
    |> validate_inclusion(:key, @valid_keys)
    |> put_default_id()
    |> put_updated_at()
  end

  defp put_default_id(changeset) do
    case get_field(changeset, :id) do
      nil -> put_change(changeset, :id, 1)
      _ -> changeset
    end
  end

  defp put_updated_at(changeset) do
    case get_field(changeset, :updated_at) do
      nil -> put_change(changeset, :updated_at, DateTime.utc_now())
      _ -> changeset
    end
  end
end
