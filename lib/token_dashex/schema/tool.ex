defmodule TokenDashex.Schema.Tool do
  @moduledoc """
  A single tool invocation embedded in an assistant message.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "tools" do
    field :session_id, :string
    field :name, :string
    field :target, :string
    field :input_tokens, :integer, default: 0
    field :output_tokens, :integer, default: 0
    field :result_tokens, :integer, default: 0

    belongs_to :message, TokenDashex.Schema.Message,
      type: :string,
      foreign_key: :message_id,
      references: :id

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @required ~w(message_id session_id name)a
  @optional ~w(target input_tokens output_tokens result_tokens)a

  def changeset(struct, params) do
    struct
    |> cast(params, @required ++ @optional)
    |> validate_required(@required)
    |> validate_number(:input_tokens, greater_than_or_equal_to: 0)
    |> validate_number(:output_tokens, greater_than_or_equal_to: 0)
    |> validate_number(:result_tokens, greater_than_or_equal_to: 0)
  end
end
