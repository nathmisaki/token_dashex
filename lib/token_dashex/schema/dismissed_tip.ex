defmodule TokenDashex.Schema.DismissedTip do
  @moduledoc """
  Records that a tip key was dismissed by the user. Tips dismissed within the
  trailing 14-day window are suppressed; older entries naturally expire.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:key, :string, autogenerate: false}

  schema "dismissed_tips" do
    field :dismissed_at, :utc_datetime_usec
  end

  @required ~w(key dismissed_at)a

  def changeset(struct, params) do
    struct
    |> cast(params, @required)
    |> validate_required(@required)
  end
end
