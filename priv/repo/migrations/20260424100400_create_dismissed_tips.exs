defmodule TokenDashex.Repo.Migrations.CreateDismissedTips do
  use Ecto.Migration

  def change do
    create table(:dismissed_tips, primary_key: false) do
      add :key, :string, primary_key: true
      add :dismissed_at, :utc_datetime_usec, null: false
    end
  end
end
