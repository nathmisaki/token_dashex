defmodule TokenDashex.Repo.Migrations.SplitCacheCreationTokens do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :cache_creation_5m_tokens, :integer, default: 0, null: false
      add :cache_creation_1h_tokens, :integer, default: 0, null: false
    end

    # Best-effort back-fill: legacy rows only knew the flat total, so treat
    # existing `cache_creation_tokens` as the 5-minute bucket. New scans will
    # populate both columns from the nested JSONL payload.
    execute(
      "UPDATE messages SET cache_creation_5m_tokens = cache_creation_tokens WHERE cache_creation_5m_tokens = 0 AND cache_creation_tokens > 0",
      ""
    )
  end
end
