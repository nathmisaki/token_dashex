defmodule TokenDashex.Schema.FileState do
  @moduledoc """
  Tracks scanner state per JSONL file so re-scans are incremental.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:path, :string, autogenerate: false}

  schema "file_states" do
    field :mtime, :utc_datetime_usec
    field :byte_offset, :integer, default: 0
    field :last_scan_at, :utc_datetime_usec
  end

  @required ~w(path mtime last_scan_at)a
  @optional ~w(byte_offset)a

  def changeset(struct, params) do
    struct
    |> cast(params, @required ++ @optional)
    |> validate_required(@required)
    |> validate_number(:byte_offset, greater_than_or_equal_to: 0)
  end
end
