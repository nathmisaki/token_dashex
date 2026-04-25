defmodule TokenDashex.Repo.Migrations.CreateTools do
  use Ecto.Migration

  def change do
    create table(:tools, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :message_id, references(:messages, type: :string, on_delete: :delete_all), null: false
      add :session_id, :string, null: false
      add :name, :string, null: false
      add :input_tokens, :integer, default: 0, null: false
      add :output_tokens, :integer, default: 0, null: false
      add :result_tokens, :integer, default: 0, null: false
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:tools, [:message_id])
    create index(:tools, [:session_id])
    create index(:tools, [:name])
  end
end
