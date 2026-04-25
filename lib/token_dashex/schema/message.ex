defmodule TokenDashex.Schema.Message do
  @moduledoc """
  Persistent record of a single Claude Code message captured from a session JSONL.

  The synthesized primary key `id` follows the pattern `"<session_id>:<message_id>"`
  so that streaming snapshot updates can be re-played idempotently.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}

  schema "messages" do
    field :session_id, :string
    field :message_id, :string
    field :project_slug, :string
    field :role, :string
    field :model, :string
    field :input_tokens, :integer, default: 0
    field :output_tokens, :integer, default: 0
    field :cache_creation_tokens, :integer, default: 0
    field :cache_creation_5m_tokens, :integer, default: 0
    field :cache_creation_1h_tokens, :integer, default: 0
    field :cache_read_tokens, :integer, default: 0
    field :uuid, :string
    field :parent_uuid, :string
    field :prompt_text, :string
    field :response_text, :string
    field :cwd, :string
    field :timestamp, :utc_datetime_usec

    has_many :tools, TokenDashex.Schema.Tool, foreign_key: :message_id
  end

  @required ~w(id session_id message_id project_slug role timestamp)a
  @optional ~w(uuid parent_uuid model input_tokens output_tokens cache_creation_tokens cache_creation_5m_tokens cache_creation_1h_tokens cache_read_tokens prompt_text response_text cwd)a
  @valid_roles ~w(user assistant system)

  def changeset(struct, params) do
    struct
    |> cast(params, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:role, @valid_roles)
    |> validate_number(:input_tokens, greater_than_or_equal_to: 0)
    |> validate_number(:output_tokens, greater_than_or_equal_to: 0)
    |> validate_number(:cache_creation_tokens, greater_than_or_equal_to: 0)
    |> validate_number(:cache_creation_5m_tokens, greater_than_or_equal_to: 0)
    |> validate_number(:cache_creation_1h_tokens, greater_than_or_equal_to: 0)
    |> validate_number(:cache_read_tokens, greater_than_or_equal_to: 0)
  end
end
