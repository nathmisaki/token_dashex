defmodule TokenDashex.Repo.Migrations.AddSidechainToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :is_sidechain, :boolean, default: false, null: false
      add :agent_id, :string, null: true
    end

    create index(:messages, [:is_sidechain])
    create index(:messages, [:agent_id])
  end
end
