defmodule TokenDashex.Repo.Migrations.AddCwdToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :cwd, :string
    end

    create index(:messages, [:cwd])
  end
end
