defmodule TokenDashex.Repo.Migrations.CreatePlan do
  use Ecto.Migration

  def change do
    create table(:plan, primary_key: false) do
      add :id, :integer, primary_key: true
      add :key, :string, null: false
      add :updated_at, :utc_datetime_usec, null: false
    end

    execute(
      """
      INSERT INTO plan (id, key, updated_at)
      VALUES (1, 'api', strftime('%Y-%m-%d %H:%M:%f', 'now'))
      """,
      "DELETE FROM plan WHERE id = 1"
    )
  end
end
