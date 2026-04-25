defmodule TokenDashex.Repo.Migrations.AddTargetToTools do
  use Ecto.Migration

  def change do
    alter table(:tools) do
      add :target, :string, null: true
    end

    create index(:tools, [:name, :target, :session_id])
  end
end
