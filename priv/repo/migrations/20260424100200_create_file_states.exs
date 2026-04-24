defmodule TokenDashex.Repo.Migrations.CreateFileStates do
  use Ecto.Migration

  def change do
    create table(:file_states, primary_key: false) do
      add :path, :string, primary_key: true
      add :mtime, :utc_datetime_usec, null: false
      add :byte_offset, :integer, default: 0, null: false
      add :last_scan_at, :utc_datetime_usec, null: false
    end
  end
end
