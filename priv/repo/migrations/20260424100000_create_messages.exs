defmodule TokenDashex.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages, primary_key: false) do
      add :id, :string, primary_key: true
      add :session_id, :string, null: false
      add :message_id, :string, null: false
      add :project_slug, :string, null: false
      add :role, :string, null: false
      add :model, :string
      add :input_tokens, :integer, default: 0, null: false
      add :output_tokens, :integer, default: 0, null: false
      add :cache_creation_tokens, :integer, default: 0, null: false
      add :cache_read_tokens, :integer, default: 0, null: false
      add :prompt_text, :text
      add :response_text, :text
      add :timestamp, :utc_datetime_usec, null: false
    end

    create index(:messages, [:session_id])
    create index(:messages, [:project_slug])
    create index(:messages, [:timestamp])
    create index(:messages, [:model])
  end
end
