defmodule TokenDashex.Repo.Migrations.AddUuidParentUuidToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :uuid, :string
      add :parent_uuid, :string
    end

    create index(:messages, [:uuid])
    create index(:messages, [:parent_uuid])
  end
end
