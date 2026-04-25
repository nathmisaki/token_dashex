# Token Dashboard: Python → Phoenix LiveView Migration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the Python `token-dashboard` (stdlib-only Claude Code usage analytics tool) to an idiomatic Elixir/Phoenix 1.8 + LiveView 1.1 application named `token_dashex`, preserving 100% feature parity (7 dashboard tabs, JSONL scanner with incremental dedup, SQLite storage, rule-based tips engine, skills catalog, pricing/cost engine, plan switching, CLI commands) while replacing SSE polling with native LiveView/PubSub real-time updates.

**Architecture:** Single Phoenix app. Local-first SQLite store (via `ecto_sqlite3`) at `~/.claude/token-dashex.db`. JSONL scanner runs as a `GenServer` driven by `Process.send_after/3` (every 30s) and broadcasts deltas via `Phoenix.PubSub` so LiveViews refresh without SSE. Pure-functional modules for parsing, pricing, tips and skills. Seven `live` routes mirroring the Python tabs. ECharts kept (vendored) and wrapped in a LiveView `Hook` so JS state survives `phx-update`. CLI exposed as `mix dashex.*` tasks; optional `escript` build for standalone distribution.

**Tech Stack:** Elixir 1.15+, Phoenix 1.8.1, LiveView 1.1, Ecto SQL 3.13 + `ecto_sqlite3`, Bandit, Phoenix.PubSub, Tailwind v4 + daisyUI, esbuild, ECharts (vendored), Req (HTTP), Jason, Telemetry, ExUnit, ExCoveralls (optional).

---

## Decisions & Assumptions

| Concern | Choice | Rationale |
|-|-|
| Database | SQLite via `ecto_sqlite3` | Original tool is single-user/local; PostgreSQL adds install friction. Mirrors Python behavior. |
| DB path | `~/.claude/token-dashex.db` | Distinct from Python's `token-dashboard.db` to allow side-by-side testing. |
| Real-time | LiveView + PubSub | Drops SSE entirely; LiveView already pushes diffs over WS. |
| Scanner trigger | GenServer + `send_after` | Matches Python's 30s polling; can be swapped for `FileSystem` later. |
| Charts | ECharts via Hook | Keep parity; daisyUI/Tailwind handle layout. |
| Pricing source | `priv/pricing.json` | Same JSON format as Python; loaded once at boot into `:persistent_term`. |
| CLI | Mix tasks first; `escript` later | Easier to test, no compile step for users running from source. |
| Frontend build | esbuild + Tailwind (already in skeleton) | No bespoke JS framework; LiveView + hooks. |
| Tests | ExUnit + Phoenix.LiveViewTest + Mox where needed | Mirror the 68 Python tests. |
| Authentication | None | Bind to `127.0.0.1` only (same as Python). |
| Migrations | Ecto migrations replicate Python schema 1:1 | One migration per logical table for traceability. |

**Out of scope (for now):** multi-user, cloud sync, plugin-local skill scan (carried over as known gap), subagent attribution.

---

## Target File Structure

```
token_dashex/
├── lib/
│   ├── token_dashex.ex                          # app root (existing)
│   ├── token_dashex/
│   │   ├── application.ex                       # supervision tree (modify)
│   │   ├── repo.ex                              # Ecto.Repo (existing)
│   │   ├── mailer.ex                            # delete (unused)
│   │   ├── paths.ex                             # NEW: ~/.claude path helpers
│   │   ├── pricing.ex                           # NEW: pricing.json loader + cost calc
│   │   ├── pricing/plan.ex                      # NEW: plan struct + persistence
│   │   ├── scanner.ex                           # NEW: pure JSONL parser
│   │   ├── scanner/parser.ex                    # NEW: parse_record, _usage, _tools…
│   │   ├── scanner/dedup.ex                     # NEW: snapshot dedup by msg id
│   │   ├── scanner/walker.ex                    # NEW: project dir walk + slug
│   │   ├── scanner/worker.ex                    # NEW: GenServer (30s tick)
│   │   ├── scanner/state.ex                     # NEW: file state (mtime/offset)
│   │   ├── ingest.ex                            # NEW: orchestrates parse → repo upserts
│   │   ├── skills.ex                            # NEW: skills catalog scanner
│   │   ├── tips.ex                              # NEW: tips dispatcher
│   │   ├── tips/cache_discipline.ex             # NEW: rule
│   │   ├── tips/repeated_reads.ex               # NEW: rule
│   │   ├── tips/oversized_results.ex            # NEW: rule
│   │   ├── tips/expensive_sessions.ex           # NEW: rule
│   │   ├── tips/skill_efficiency.ex             # NEW: rule
│   │   ├── analytics.ex                         # NEW: query layer (overview, prompts, …)
│   │   ├── analytics/overview.ex                # NEW
│   │   ├── analytics/prompts.ex                 # NEW
│   │   ├── analytics/sessions.ex                # NEW
│   │   ├── analytics/projects.ex                # NEW
│   │   ├── analytics/tools.ex                   # NEW
│   │   ├── analytics/daily.ex                   # NEW
│   │   ├── analytics/by_model.ex                # NEW
│   │   ├── schema/message.ex                    # NEW: Ecto schema
│   │   ├── schema/tool.ex                       # NEW
│   │   ├── schema/file_state.ex                 # NEW
│   │   ├── schema/plan.ex                       # NEW
│   │   ├── schema/dismissed_tip.ex              # NEW
│   │   └── pubsub_topics.ex                     # NEW: topic constants
│   └── token_dashex_web/
│       ├── endpoint.ex                          # existing
│       ├── router.ex                            # MODIFY: add live routes
│       ├── telemetry.ex                         # existing
│       ├── components/core_components.ex        # existing (extend)
│       ├── components/layouts.ex                # existing (modify nav)
│       ├── live/overview_live.ex                # NEW
│       ├── live/prompts_live.ex                 # NEW
│       ├── live/sessions_live.ex                # NEW
│       ├── live/session_show_live.ex            # NEW (drill-down)
│       ├── live/projects_live.ex                # NEW
│       ├── live/skills_live.ex                  # NEW
│       ├── live/tips_live.ex                    # NEW
│       ├── live/settings_live.ex                # NEW
│       ├── live/dashboard_layout.ex             # NEW (shared topbar component)
│       └── controllers/page_controller.ex       # delete (replaced by live "/")
├── priv/
│   ├── repo/migrations/                         # NEW: 5 migrations
│   ├── pricing.json                             # NEW: copy of Python pricing.json
│   ├── static/                                  # existing
│   └── echarts/echarts.min.js                   # NEW: vendored
├── assets/
│   ├── js/app.js                                # MODIFY: register hooks
│   ├── js/hooks/echarts_hook.js                 # NEW
│   └── css/app.css                              # MODIFY: import daisyUI dark theme
├── test/
│   ├── token_dashex/
│   │   ├── scanner/parser_test.exs
│   │   ├── scanner/dedup_test.exs
│   │   ├── scanner/walker_test.exs
│   │   ├── scanner/worker_test.exs
│   │   ├── ingest_test.exs
│   │   ├── pricing_test.exs
│   │   ├── skills_test.exs
│   │   ├── tips_test.exs
│   │   ├── analytics/overview_test.exs
│   │   ├── analytics/prompts_test.exs
│   │   ├── analytics/sessions_test.exs
│   │   └── analytics/by_model_test.exs
│   ├── token_dashex_web/live/
│   │   ├── overview_live_test.exs
│   │   ├── prompts_live_test.exs
│   │   ├── sessions_live_test.exs
│   │   ├── projects_live_test.exs
│   │   ├── skills_live_test.exs
│   │   ├── tips_live_test.exs
│   │   └── settings_live_test.exs
│   ├── support/
│   │   ├── data_case.ex                         # MODIFY for sqlite sandbox
│   │   ├── conn_case.ex                         # existing
│   │   └── jsonl_fixtures.ex                    # NEW
│   └── fixtures/jsonl/*.jsonl                   # NEW: sample sessions
└── docs/superpowers/plans/
    └── 2026-04-24-python-to-phoenix-migration.md (this file)
```

---

# Phase 1 — Foundation

## Task 1.1: Replace Postgrex with ecto_sqlite3

**Files:**
- Modify: `mix.exs`
- Modify: `config/config.exs`
- Modify: `config/dev.exs`
- Modify: `config/test.exs`
- Modify: `config/runtime.exs`
- Modify: `lib/token_dashex/repo.ex`

- [ ] **Step 1: Edit `mix.exs` deps** — remove `:postgrex`, add `{:ecto_sqlite3, "~> 0.17"}`. Save.

```elixir
defp deps do
  [
    {:phoenix, "~> 1.8.1"},
    {:phoenix_ecto, "~> 4.5"},
    {:ecto_sql, "~> 3.13"},
    {:ecto_sqlite3, "~> 0.17"},
    # …keep the rest (LiveView, Bandit, Tailwind, esbuild, Req, etc.)
    # remove: {:swoosh, ...}, {:gen_smtp, ...}  (we don't email)
  ]
end
```

- [ ] **Step 2: Run `mix deps.get`** — expect `:postgrex` removed, `:ecto_sqlite3` added.

- [ ] **Step 3: Update `lib/token_dashex/repo.ex`** to use SQLite adapter:

```elixir
defmodule TokenDashex.Repo do
  use Ecto.Repo,
    otp_app: :token_dashex,
    adapter: Ecto.Adapters.SQLite3
end
```

- [ ] **Step 4: Update `config/config.exs`** repo block:

```elixir
config :token_dashex, TokenDashex.Repo,
  database: Path.expand("~/.claude/token-dashex.db"),
  journal_mode: :wal,
  cache_size: -64_000,
  pool_size: 5
```

- [ ] **Step 5: Update `config/dev.exs`** — remove postgres host/user/pass, set DB to a dev-local file:

```elixir
config :token_dashex, TokenDashex.Repo,
  database: Path.expand("./priv/repo/dev.db"),
  pool_size: 5,
  show_sensitive_data_on_connection_error: true
```

- [ ] **Step 6: Update `config/test.exs`** — use `:memory` SQLite per test:

```elixir
config :token_dashex, TokenDashex.Repo,
  database: ":memory:",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 5
```

- [ ] **Step 7: Update `config/runtime.exs`** — for prod/release, read DB path from env:

```elixir
if config_env() == :prod do
  db_path =
    System.get_env("TOKEN_DASHEX_DB") ||
      Path.expand("~/.claude/token-dashex.db")

  config :token_dashex, TokenDashex.Repo,
    database: db_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")
end
```

- [ ] **Step 8: Run `mix compile`** — expect zero warnings.

- [ ] **Step 9: Run `mix ecto.create`** — expect dev DB file at `priv/repo/dev.db`.

- [ ] **Step 10: Commit**

```bash
git add mix.exs mix.lock config/ lib/token_dashex/repo.ex
git commit -m "chore(db): replace Postgrex with ecto_sqlite3"
```

## Task 1.2: Drop unused mailer + page controller

**Files:**
- Delete: `lib/token_dashex/mailer.ex`
- Delete: `lib/token_dashex_web/controllers/page_controller.ex`
- Delete: `lib/token_dashex_web/controllers/page_html.ex` (if exists)
- Delete: `lib/token_dashex_web/controllers/page_html/home.html.heex` (if exists)
- Modify: `lib/token_dashex/application.ex` (remove `Finch` if only used by mailer)
- Modify: `lib/token_dashex_web/router.ex`
- Modify: `mix.exs` (drop `:swoosh`, `:gen_smtp`, `:finch` if unused)

- [ ] **Step 1: Remove mailer module + dev mailbox route** from router (`/dev/mailbox`).

- [ ] **Step 2: Remove `TokenDashex.Mailer` from `application.ex` children if listed.**

- [ ] **Step 3: Drop `:swoosh, :gen_smtp` from `mix.exs`; run `mix deps.unlock --unused && mix deps.clean --unused`.**

- [ ] **Step 4: `mix compile`** — zero warnings.

- [ ] **Step 5: Commit**

```bash
git commit -am "chore: drop mailer + default page scaffolding"
```

## Task 1.3: Add `TokenDashex.Paths` helper module

**Files:**
- Create: `lib/token_dashex/paths.ex`
- Test: `test/token_dashex/paths_test.exs`

- [ ] **Step 1: Write failing test**

```elixir
defmodule TokenDashex.PathsTest do
  use ExUnit.Case, async: true
  alias TokenDashex.Paths

  test "projects_dir/0 honors CLAUDE_PROJECTS_DIR env" do
    System.put_env("CLAUDE_PROJECTS_DIR", "/tmp/jsonl")
    assert Paths.projects_dir() == "/tmp/jsonl"
  after
    System.delete_env("CLAUDE_PROJECTS_DIR")
  end

  test "projects_dir/0 defaults to ~/.claude/projects" do
    System.delete_env("CLAUDE_PROJECTS_DIR")
    assert Paths.projects_dir() == Path.expand("~/.claude/projects")
  end

  test "db_path/0 honors TOKEN_DASHEX_DB env" do
    System.put_env("TOKEN_DASHEX_DB", "/tmp/x.db")
    assert Paths.db_path() == "/tmp/x.db"
  after
    System.delete_env("TOKEN_DASHEX_DB")
  end

  test "skills_roots/0 returns 3 expanded paths" do
    paths = Paths.skills_roots()
    assert length(paths) == 3
    assert Enum.all?(paths, &String.contains?(&1, "/.claude/"))
  end
end
```

- [ ] **Step 2: Run tests, expect FAIL.**

- [ ] **Step 3: Implement**

```elixir
defmodule TokenDashex.Paths do
  @moduledoc false

  def projects_dir do
    System.get_env("CLAUDE_PROJECTS_DIR") || Path.expand("~/.claude/projects")
  end

  def db_path do
    System.get_env("TOKEN_DASHEX_DB") || Path.expand("~/.claude/token-dashex.db")
  end

  def skills_roots do
    [
      Path.expand("~/.claude/skills"),
      Path.expand("~/.claude/scheduled-tasks"),
      Path.expand("~/.claude/plugins")
    ]
  end
end
```

- [ ] **Step 4: Re-run tests, expect PASS.**

- [ ] **Step 5: Commit**

```bash
git commit -am "feat(paths): add path helpers for ~/.claude resources"
```

---

# Phase 2 — Database Schema

Replicates Python's SQLite schema 1:1: `messages`, `tools`, `files`, `plan`, `dismissed_tips`.

## Task 2.1: `messages` table migration + schema

**Files:**
- Create: `priv/repo/migrations/20260424100000_create_messages.exs`
- Create: `lib/token_dashex/schema/message.ex`
- Test: `test/token_dashex/schema/message_test.exs`

- [ ] **Step 1: Generate migration**

```bash
mix ecto.gen.migration create_messages
```

(Replace generated file with the exact name above.)

- [ ] **Step 2: Migration contents**

```elixir
defmodule TokenDashex.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages, primary_key: false) do
      add :id, :string, primary_key: true       # synthesized "<session_id>:<message_id>"
      add :session_id, :string, null: false
      add :message_id, :string, null: false
      add :project_slug, :string, null: false
      add :role, :string, null: false           # "user" | "assistant"
      add :model, :string
      add :input_tokens, :integer, default: 0
      add :output_tokens, :integer, default: 0
      add :cache_creation_tokens, :integer, default: 0
      add :cache_read_tokens, :integer, default: 0
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
```

- [ ] **Step 3: Schema module**

```elixir
defmodule TokenDashex.Schema.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  schema "messages" do
    field :session_id, :string
    field :message_id, :string
    field :project_slug, :string
    field :role, :string
    field :model, :string
    field :input_tokens, :integer, default: 0
    field :output_tokens, :integer, default: 0
    field :cache_creation_tokens, :integer, default: 0
    field :cache_read_tokens, :integer, default: 0
    field :prompt_text, :string
    field :response_text, :string
    field :timestamp, :utc_datetime_usec
    has_many :tools, TokenDashex.Schema.Tool, foreign_key: :message_id
  end

  @required ~w(id session_id message_id project_slug role timestamp)a
  @optional ~w(model input_tokens output_tokens cache_creation_tokens cache_read_tokens prompt_text response_text)a

  def changeset(struct, params) do
    struct
    |> cast(params, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:role, ~w(user assistant system))
  end
end
```

- [ ] **Step 4: Test changeset rejects missing required fields.** Implement, run, commit.

```bash
git commit -am "feat(db): messages table + schema"
```

## Task 2.2: `tools` table

Same shape as Task 2.1.

**Schema fields:** `id` (uuid), `message_id` (FK), `session_id`, `name`, `input_tokens`, `output_tokens`, `result_tokens`, `inserted_at`. Foreign key to `messages.id` with `on_delete: :delete_all`.

- [ ] Migration `20260424100100_create_tools.exs`
- [ ] Schema `lib/token_dashex/schema/tool.ex`
- [ ] Test `test/token_dashex/schema/tool_test.exs`
- [ ] Commit `feat(db): tools table + schema`

## Task 2.3: `file_states` table

Tracks scanner state. Columns: `path` (PK), `mtime` (utc_datetime_usec), `byte_offset` (integer), `last_scan_at` (utc_datetime_usec).

- [ ] Migration `20260424100200_create_file_states.exs`
- [ ] Schema `lib/token_dashex/schema/file_state.ex`
- [ ] Test `test/token_dashex/schema/file_state_test.exs`
- [ ] Commit `feat(db): file scan state table`

## Task 2.4: `plan` table

Single row holds active plan key (`"api"|"pro"|"max"|"max-20x"`). Columns: `id` (always 1, PK), `key` (string), `updated_at`.

- [ ] Migration `20260424100300_create_plan.exs` — also seed default `("1","api")` row.
- [ ] Schema `lib/token_dashex/schema/plan.ex`
- [ ] Test
- [ ] Commit `feat(db): plan persistence table`

## Task 2.5: `dismissed_tips` table

Columns: `key` (PK), `dismissed_at` (utc_datetime_usec).

- [ ] Migration `20260424100400_create_dismissed_tips.exs`
- [ ] Schema
- [ ] Test
- [ ] Commit `feat(db): dismissed tips table`

## Task 2.6: Run all migrations, lock baseline

- [ ] `mix ecto.migrate` — expect 5 migrations applied.
- [ ] Verify schema with `sqlite3 priv/repo/dev.db ".schema"`.
- [ ] Commit migration lock if any.

---

# Phase 3 — Pricing Engine

Mirror `token_dashboard/pricing.py`.

## Task 3.1: Copy `pricing.json` into priv

**Files:**
- Create: `priv/pricing.json` (copy of `/Users/misaki/code/me/token-dashboard/pricing.json`)

- [ ] Copy file verbatim.
- [ ] Commit `chore: vendor pricing.json from upstream`.

## Task 3.2: `TokenDashex.Pricing` loader + cost calc

**Files:**
- Create: `lib/token_dashex/pricing.ex`
- Test: `test/token_dashex/pricing_test.exs`

- [ ] **Step 1: Failing tests** — load pricing, cost_for/3 returns USD float, fallback when model unknown.

```elixir
defmodule TokenDashex.PricingTest do
  use ExUnit.Case, async: true
  alias TokenDashex.Pricing

  setup do
    Pricing.reload!()
    :ok
  end

  test "models/0 returns map of model rates" do
    models = Pricing.models()
    assert is_map(models["claude-sonnet-4-6"])
    assert is_number(models["claude-sonnet-4-6"]["input"])
  end

  test "cost_for/3 calculates USD from usage" do
    usage = %{
      "input_tokens" => 1_000_000,
      "output_tokens" => 500_000,
      "cache_creation_input_tokens" => 0,
      "cache_read_input_tokens" => 0
    }
    cost = Pricing.cost_for("claude-sonnet-4-6", usage)
    assert_in_delta cost, 3.0 + 7.5, 0.01  # using $3/M input, $15/M output
  end

  test "cost_for/3 with unknown model uses tier fallback" do
    cost = Pricing.cost_for("totally-unknown-model", %{"input_tokens" => 1_000})
    assert is_float(cost)
    assert cost >= 0
  end

  test "plans/0 returns plan list with monthly cost" do
    assert Enum.any?(Pricing.plans(), &(&1["key"] == "max-20x"))
  end
end
```

- [ ] **Step 2: Implementation**

```elixir
defmodule TokenDashex.Pricing do
  @moduledoc "Loads pricing.json and computes per-message USD cost."

  @table :token_dashex_pricing

  def reload! do
    json =
      :token_dashex
      |> :code.priv_dir()
      |> Path.join("pricing.json")
      |> File.read!()
      |> Jason.decode!()

    :persistent_term.put(@table, json)
    :ok
  end

  def models, do: get()["models"] || %{}
  def plans, do: get()["plans"] || []

  def cost_for(model, %{} = usage) do
    rate = Map.get(models(), model) || tier_fallback(model)
    rate_for_input = rate["input"] || 0.0
    rate_for_output = rate["output"] || 0.0
    rate_cache_create = rate["cache_creation"] || rate["cache_write"] || 0.0
    rate_cache_read = rate["cache_read"] || 0.0

    Map.get(usage, "input_tokens", 0) * rate_for_input / 1_000_000 +
      Map.get(usage, "output_tokens", 0) * rate_for_output / 1_000_000 +
      Map.get(usage, "cache_creation_input_tokens", 0) * rate_cache_create / 1_000_000 +
      Map.get(usage, "cache_read_input_tokens", 0) * rate_cache_read / 1_000_000
  end

  defp tier_fallback(model) do
    cond do
      String.contains?(model, "opus")   -> models()["claude-opus-4-7"] || %{}
      String.contains?(model, "sonnet") -> models()["claude-sonnet-4-6"] || %{}
      String.contains?(model, "haiku")  -> models()["claude-haiku-4-5"] || %{}
      true -> %{}
    end
  end

  defp get do
    case :persistent_term.get(@table, :missing) do
      :missing ->
        reload!()
        :persistent_term.get(@table)
      data -> data
    end
  end
end
```

- [ ] **Step 3:** Run tests, expect PASS.
- [ ] **Step 4: Wire into supervision** — add `Task.start(fn -> TokenDashex.Pricing.reload!() end)` in `application.ex` start/2 (or call inline before tree).
- [ ] **Step 5: Commit** `feat(pricing): JSON loader + cost calculator`.

## Task 3.3: Plan persistence (`Pricing.Plan`)

**Files:**
- Create: `lib/token_dashex/pricing/plan.ex`
- Test: `test/token_dashex/pricing/plan_test.exs`

- [ ] Test `get_plan/0` returns `"api"` by default after seed.
- [ ] Test `set_plan/1` upserts row and broadcasts via `Phoenix.PubSub` topic `"plan:changed"`.
- [ ] Implementation:

```elixir
defmodule TokenDashex.Pricing.Plan do
  alias TokenDashex.Repo
  alias TokenDashex.Schema.Plan

  @valid ~w(api pro max max-20x)

  def get do
    Repo.get(Plan, 1) |> Map.get(:key, "api")
  end

  def set(key) when key in @valid do
    %Plan{id: 1}
    |> Plan.changeset(%{key: key})
    |> Repo.insert_or_update!()

    Phoenix.PubSub.broadcast(TokenDashex.PubSub, "plan:changed", {:plan_changed, key})
    :ok
  end
end
```

- [ ] Commit `feat(pricing): plan persistence + pubsub`.

---

# Phase 4 — Scanner

Pure-functional parser + GenServer worker. Mirror `token_dashboard/scanner.py`.

## Task 4.1: JSONL fixture helper

**Files:**
- Create: `test/support/jsonl_fixtures.ex`
- Create: `test/fixtures/jsonl/simple_session.jsonl` (5 records)
- Create: `test/fixtures/jsonl/dedup_session.jsonl` (streaming snapshots same msg id)
- Create: `test/fixtures/jsonl/with_tools.jsonl` (records w/ `tool_uses`)

- [ ] Build small JSONL fixtures by extracting/synthesizing real Claude Code records.

Sample line for fixture:

```json
{"type":"assistant","message":{"id":"msg_01","model":"claude-sonnet-4-6","role":"assistant","content":[{"type":"text","text":"hi"}],"usage":{"input_tokens":10,"output_tokens":5,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}},"sessionId":"sess_a","timestamp":"2026-04-24T10:00:00Z"}
```

- [ ] Helper:

```elixir
defmodule TokenDashex.JsonlFixtures do
  @root "test/fixtures/jsonl"
  def path(name), do: Path.join(@root, name)
  def stream(name), do: path(name) |> File.stream!() |> Stream.map(&Jason.decode!(String.trim_trailing(&1)))
end
```

- [ ] Commit `test: JSONL fixtures + helper`.

## Task 4.2: `Scanner.Parser` — record → parsed map

**Files:**
- Create: `lib/token_dashex/scanner/parser.ex`
- Test: `test/token_dashex/scanner/parser_test.exs`

- [ ] **Failing tests** (mirror `test_scanner_parse.py`):
  - `parse_record/2` returns `{:ok, %{role:, message_id:, usage:, tools:, prompt_text:, ...}}` for assistant record
  - returns `{:ok, %{role: "user", prompt_text: "..."}}` for user record
  - returns `:skip` for system records
  - extracts tools from `message.content[].type == "tool_use"`
  - estimates result tokens via `result_chars/4`

- [ ] **Implement** — pure functions, no I/O:

```elixir
defmodule TokenDashex.Scanner.Parser do
  @moduledoc false

  def parse_record(%{"type" => "assistant", "message" => msg} = rec, project_slug) do
    {:ok, %{
      role: "assistant",
      session_id: rec["sessionId"],
      message_id: msg["id"],
      project_slug: project_slug,
      model: msg["model"],
      timestamp: parse_ts(rec["timestamp"]),
      usage: usage(msg["usage"] || %{}),
      prompt_text: nil,
      response_text: response_text(msg["content"]),
      tools: tools(msg["content"])
    }}
  end

  def parse_record(%{"type" => "user", "message" => msg} = rec, project_slug) do
    {:ok, %{
      role: "user",
      session_id: rec["sessionId"],
      message_id: msg["id"] || rec["uuid"],
      project_slug: project_slug,
      model: nil,
      timestamp: parse_ts(rec["timestamp"]),
      usage: %{},
      prompt_text: prompt_text(msg["content"]),
      response_text: nil,
      tools: []
    }}
  end

  def parse_record(_, _), do: :skip

  defp usage(u) do
    Map.take(u, ~w(input_tokens output_tokens cache_creation_input_tokens cache_read_input_tokens))
  end

  defp prompt_text(content) when is_binary(content), do: content
  defp prompt_text(content) when is_list(content) do
    content
    |> Enum.filter(&(&1["type"] == "text"))
    |> Enum.map_join("\n", & &1["text"])
  end
  defp prompt_text(_), do: nil

  defp response_text(content) when is_list(content) do
    content
    |> Enum.filter(&(&1["type"] == "text"))
    |> Enum.map_join("\n", & &1["text"])
  end
  defp response_text(_), do: nil

  defp tools(content) when is_list(content) do
    Enum.filter(content, &(&1["type"] == "tool_use"))
    |> Enum.map(fn tu ->
      input = Jason.encode!(tu["input"] || %{})
      %{
        name: tu["name"],
        input_tokens: round(byte_size(input) / 4),
        output_tokens: 0
      }
    end)
  end
  defp tools(_), do: []

  defp parse_ts(nil), do: DateTime.utc_now()
  defp parse_ts(iso) do
    {:ok, dt, _} = DateTime.from_iso8601(iso)
    dt
  end
end
```

- [ ] Run tests, expect PASS.
- [ ] Commit `feat(scanner): pure JSONL record parser`.

## Task 4.3: `Scanner.Dedup` — collapse streaming snapshots

**Files:**
- Create: `lib/token_dashex/scanner/dedup.ex`
- Test: `test/token_dashex/scanner/dedup_test.exs`

- [ ] **Failing test**: stream of 3 records with same `(session_id, message_id)` and increasing `output_tokens` should yield 1 record (the last one).

```elixir
test "keeps last snapshot per (session_id, message_id)" do
  records = [
    %{session_id: "s", message_id: "m", usage: %{"output_tokens" => 1}},
    %{session_id: "s", message_id: "m", usage: %{"output_tokens" => 5}},
    %{session_id: "s", message_id: "m", usage: %{"output_tokens" => 10}}
  ]
  assert [%{usage: %{"output_tokens" => 10}}] = Dedup.collapse(records)
end
```

- [ ] **Implement** as `Stream.transform` keeping `Map` of latest, then yielding values.

```elixir
defmodule TokenDashex.Scanner.Dedup do
  def collapse(records) do
    records
    |> Enum.reduce(%{}, fn r, acc ->
      Map.put(acc, {r.session_id, r.message_id}, r)
    end)
    |> Map.values()
  end
end
```

- [ ] Commit `feat(scanner): snapshot dedup`.

## Task 4.4: `Scanner.Walker` — find JSONL files + slug projects

**Files:**
- Create: `lib/token_dashex/scanner/walker.ex`
- Test: `test/token_dashex/scanner/walker_test.exs`

- [ ] **Tests:**
  - `walk(dir)` returns `[{path, project_slug}]` for every `*.jsonl` under it
  - `project_slug/1` derives slug from immediate parent dir, replacing `/` with `--`
  - skips files matching `.tmp` extension

- [ ] **Implementation:**

```elixir
defmodule TokenDashex.Scanner.Walker do
  def walk(root) do
    case File.exists?(root) do
      false -> []
      true ->
        Path.wildcard(Path.join(root, "**/*.jsonl"))
        |> Enum.map(fn p -> {p, project_slug(p, root)} end)
    end
  end

  def project_slug(path, root) do
    path
    |> Path.relative_to(root)
    |> Path.dirname()
    |> String.replace("/", "--")
  end
end
```

- [ ] Commit `feat(scanner): directory walker + slug derivation`.

## Task 4.5: `Ingest` — parsed records → DB upserts

**Files:**
- Create: `lib/token_dashex/ingest.ex`
- Test: `test/token_dashex/ingest_test.exs`

- [ ] **Failing tests** (uses real Repo via SQL sandbox):
  - given list of parsed records, inserts messages with `id = "session:msg"` (idempotent)
  - tools written under each message
  - re-running with same record updates token counts (last-write-wins)

- [ ] **Implement** using `Repo.insert_all/3` with `on_conflict: {:replace_all_except, [:id]}`:

```elixir
defmodule TokenDashex.Ingest do
  alias TokenDashex.Repo
  alias TokenDashex.Schema.{Message, Tool}

  def upsert_records(records) when is_list(records) do
    Repo.transaction(fn ->
      Enum.each(records, &upsert/1)
    end)
  end

  defp upsert(rec) do
    msg = %{
      id: "#{rec.session_id}:#{rec.message_id}",
      session_id: rec.session_id,
      message_id: rec.message_id,
      project_slug: rec.project_slug,
      role: rec.role,
      model: rec.model,
      input_tokens: rec.usage["input_tokens"] || 0,
      output_tokens: rec.usage["output_tokens"] || 0,
      cache_creation_tokens: rec.usage["cache_creation_input_tokens"] || 0,
      cache_read_tokens: rec.usage["cache_read_input_tokens"] || 0,
      prompt_text: rec.prompt_text,
      response_text: rec.response_text,
      timestamp: rec.timestamp
    }

    Repo.insert_all(Message, [msg],
      on_conflict: {:replace_all_except, [:id]},
      conflict_target: :id
    )

    Repo.delete_all(from t in Tool, where: t.message_id == ^msg.id)

    tools =
      Enum.map(rec.tools, fn t ->
        %{
          id: Ecto.UUID.generate(),
          message_id: msg.id,
          session_id: rec.session_id,
          name: t.name,
          input_tokens: t.input_tokens,
          output_tokens: t.output_tokens
        }
      end)

    if tools != [], do: Repo.insert_all(Tool, tools)
  end
end
```

- [ ] Commit `feat(ingest): record upserts with replay safety`.

## Task 4.6: `Scanner.Worker` — GenServer ticker

**Files:**
- Create: `lib/token_dashex/scanner/worker.ex`
- Test: `test/token_dashex/scanner/worker_test.exs`

State holds `%{root: path, interval: ms, file_states: map}`. On `:tick`:
1. `Walker.walk/1`
2. For each `{path, slug}`, compare `File.stat!(path).mtime` vs stored `mtime`. If newer or unseen, read from `byte_offset` to EOF, parse lines, dedupe with stored msg ids, ingest, update offset.
3. Broadcast `{:scan_complete, summary}` on `"scanner"` topic.
4. Schedule next tick.

- [ ] **Failing test**: spawn worker pointed at fixture dir, send manual tick (`GenServer.call(:tick)` testing API), assert messages exist in DB.
- [ ] **Implement** with explicit `:tick` message + manual `tick/1` call for tests.
- [ ] Add to supervision tree (Phase 1.5).
- [ ] Commit `feat(scanner): periodic GenServer worker`.

## Task 4.7: Wire scanner into `application.ex`

**Files:**
- Modify: `lib/token_dashex/application.ex`

- [ ] Add child after `Repo` and `PubSub`:

```elixir
{TokenDashex.Scanner.Worker, root: TokenDashex.Paths.projects_dir(), interval: 30_000}
```

- [ ] Make startup tolerant of missing `~/.claude/projects`: worker logs warning and idles if dir absent.
- [ ] Commit `chore(app): supervise scanner worker`.

---

# Phase 5 — Skills Catalog

Mirror `token_dashboard/skills.py`.

## Task 5.1: `TokenDashex.Skills`

**Files:**
- Create: `lib/token_dashex/skills.ex`
- Test: `test/token_dashex/skills_test.exs`

- [ ] **Tests:**
  - `catalog/0` returns `[%{slug, path, est_tokens}]` for every `SKILL.md` under each root
  - slug for `~/.claude/plugins/foo/skills/bar/SKILL.md` is `"foo:bar"`
  - slug for `~/.claude/skills/baz/SKILL.md` is `"baz"`
  - estimates tokens as `div(byte_size, 4)`
  - missing root dirs are silently skipped

- [ ] **Implement** with `Path.wildcard` + slug rules.

```elixir
defmodule TokenDashex.Skills do
  alias TokenDashex.Paths

  def catalog do
    Paths.skills_roots()
    |> Enum.flat_map(&scan_root/1)
  end

  defp scan_root(root) do
    case File.exists?(root) do
      false -> []
      true ->
        Path.wildcard(Path.join(root, "**/SKILL.md"))
        |> Enum.map(&entry(&1, root))
    end
  end

  defp entry(path, root) do
    %{
      slug: slug(path, root),
      path: path,
      est_tokens: estimate_tokens(path)
    }
  end

  defp slug(path, root) do
    rel = Path.relative_to(path, root) |> Path.dirname()
    parts = String.split(rel, "/")
    case parts do
      [plugin, "skills", skill] -> "#{plugin}:#{skill}"
      [skill] -> skill
      other -> Enum.join(other, ":")
    end
  end

  defp estimate_tokens(path) do
    case File.stat(path) do
      {:ok, %{size: s}} -> div(s, 4)
      _ -> 0
    end
  end
end
```

- [ ] Commit `feat(skills): catalog scanner`.

## Task 5.2: Skills invocation analytics

Cross-references catalog with messages whose `prompt_text` references `Skill(name="...")` or system reminders mentioning skill name.

- [ ] **Test:** seed messages mentioning `"using-superpowers"`; assert `Skills.usage_breakdown/0` returns invocation count + token totals per slug.
- [ ] Implement Ecto query joining message text against catalog slugs.
- [ ] Commit `feat(skills): invocation breakdown query`.

---

# Phase 6 — Tips Engine

Mirror `token_dashboard/tips.py`. Each rule = own module implementing behaviour `TokenDashex.Tips.Rule`.

## Task 6.1: `Tips.Rule` behaviour + dispatcher

**Files:**
- Create: `lib/token_dashex/tips.ex`
- Create: `lib/token_dashex/tips/rule.ex`
- Test: `test/token_dashex/tips_test.exs`

```elixir
defmodule TokenDashex.Tips.Rule do
  @callback evaluate() :: [%{key: String.t(), title: String.t(), body: String.t(), severity: :info | :warning}]
end
```

- [ ] **Test** dispatcher calls each rule and filters dismissed tips (within 14 days).
- [ ] **Implement:**

```elixir
defmodule TokenDashex.Tips do
  alias TokenDashex.Repo
  alias TokenDashex.Schema.DismissedTip

  @rules [
    TokenDashex.Tips.CacheDiscipline,
    TokenDashex.Tips.RepeatedReads,
    TokenDashex.Tips.OversizedResults,
    TokenDashex.Tips.ExpensiveSessions,
    TokenDashex.Tips.SkillEfficiency
  ]

  def active do
    dismissed = active_dismissals()
    @rules
    |> Enum.flat_map(& &1.evaluate())
    |> Enum.reject(&MapSet.member?(dismissed, &1.key))
  end

  def dismiss(key) do
    %DismissedTip{key: key, dismissed_at: DateTime.utc_now()}
    |> Repo.insert!(on_conflict: :replace_all, conflict_target: :key)
  end

  defp active_dismissals do
    cutoff = DateTime.utc_now() |> DateTime.add(-14 * 86_400, :second)
    Repo.all(from d in DismissedTip, where: d.dismissed_at >= ^cutoff, select: d.key)
    |> MapSet.new()
  end
end
```

- [ ] Commit `feat(tips): dispatcher + dismissal store`.

## Task 6.2: Cache discipline rule

**Logic:** Over last 7 days, if `cache_read_tokens / (cache_read_tokens + cache_creation_tokens) < 0.5`, emit warning.

- [ ] Test seeds messages, evaluates rule, asserts tip emitted.
- [ ] Implement in `lib/token_dashex/tips/cache_discipline.ex`.
- [ ] Commit `feat(tips): cache discipline rule`.

## Task 6.3: Repeated file reads rule

**Logic:** Within a session, if same `Read` tool called on same file path >5 times, emit info.

- [ ] Test, implement, commit `feat(tips): repeated reads rule`.

## Task 6.4: Oversized results rule

**Logic:** Tool result > 50k estimated tokens.

- [ ] Test, implement, commit `feat(tips): oversized result rule`.

## Task 6.5: Expensive sessions rule

**Logic:** Top-5 sessions by total cost.

- [ ] Test, implement, commit `feat(tips): expensive sessions rule`.

## Task 6.6: Skill efficiency rule

**Logic:** Compute mean tokens-per-invocation across skills; flag outliers >2σ.

- [ ] Test, implement, commit `feat(tips): skill efficiency rule`.

---

# Phase 7 — Analytics Query Layer

Each query mirrors a Python `db.py` function. Pure Ecto queries grouped by domain.

## Task 7.1: `Analytics.Overview`

**Returns:** all-time totals, today's totals, last-7-days totals, session count, project count, total cost.

- [ ] Test seeds 3 sessions across 2 projects with varied dates; assert returned struct matches expected aggregates.
- [ ] Implement single query using `select` aggregates.

```elixir
defmodule TokenDashex.Analytics.Overview do
  import Ecto.Query
  alias TokenDashex.{Repo, Schema.Message}

  def totals do
    today = Date.utc_today()
    seven_days_ago = Date.add(today, -7)

    base = from m in Message,
      select: %{
        input: sum(m.input_tokens),
        output: sum(m.output_tokens),
        cache_create: sum(m.cache_creation_tokens),
        cache_read: sum(m.cache_read_tokens),
        sessions: count(fragment("DISTINCT ?", m.session_id)),
        projects: count(fragment("DISTINCT ?", m.project_slug))
      }

    %{
      all_time: Repo.one(base),
      today: Repo.one(from m in base, where: fragment("date(?)", m.timestamp) == ^today),
      last_7d: Repo.one(from m in base, where: fragment("date(?)", m.timestamp) >= ^seven_days_ago)
    }
  end
end
```

- [ ] Commit `feat(analytics): overview query`.

## Task 7.2: `Analytics.Prompts.expensive/1`

**Args:** `%{sort: :input | :output | :total, limit: int, offset: int}`. Returns user prompts with assistant turn aggregated tokens.

- [ ] Test, implement, commit.

## Task 7.3: `Analytics.Sessions`

`recent/1` — last N sessions with totals.
`turns/1` — turn-by-turn for one session including tool calls.

- [ ] Tests for both, implement, commit.

## Task 7.4: `Analytics.Projects.summary/0`

Group by `project_slug`. Return tokens, sessions, last activity per project.

- [ ] Test, implement, commit.

## Task 7.5: `Analytics.Tools.breakdown/0`

Group tool invocations by name. Return count + total tokens.

- [ ] Test, implement, commit.

## Task 7.6: `Analytics.Daily.series/1`

Time-series: `[%{date, input, output, cache_read, cache_create, cost}]` over last 30 days.

- [ ] Test, implement, commit.

## Task 7.7: `Analytics.ByModel.breakdown/0`

Group by `model`. Apply `Pricing.cost_for/2`.

- [ ] Test, implement, commit.

---

# Phase 8 — Real-Time Backbone

## Task 8.1: PubSub topics module

**Files:**
- Create: `lib/token_dashex/pubsub_topics.ex`

```elixir
defmodule TokenDashex.PubSubTopics do
  def scanner, do: "scanner"
  def plan_changed, do: "plan:changed"
  def tips_changed, do: "tips:changed"
end
```

- [ ] Commit `feat(pubsub): topic constants`.

## Task 8.2: Scanner broadcasts on completion

- [ ] Modify `Scanner.Worker.handle_info(:tick, …)` to `Phoenix.PubSub.broadcast(TokenDashex.PubSub, PubSubTopics.scanner(), {:scan_complete, summary})`.
- [ ] Worker test asserts message arrives at subscriber.
- [ ] Commit `feat(scanner): broadcast scan completion`.

---

# Phase 9 — LiveView Dashboard

## Task 9.1: Shared layout + topbar

**Files:**
- Modify: `lib/token_dashex_web/components/layouts.ex`
- Create: `lib/token_dashex_web/components/dashboard_layout.ex`

- [ ] Build `<.topbar active={@active}>` with 7 tabs (Overview, Prompts, Sessions, Projects, Skills, Tips, Settings) using `<.link patch={~p"/..."}>`.
- [ ] Apply daisyUI `navbar` class.
- [ ] Snapshot test rendering.
- [ ] Commit `feat(ui): shared dashboard layout`.

## Task 9.2: Router additions

**Files:**
- Modify: `lib/token_dashex_web/router.ex`

```elixir
scope "/", TokenDashexWeb do
  pipe_through :browser

  live "/", OverviewLive, :index
  live "/prompts", PromptsLive, :index
  live "/sessions", SessionsLive, :index
  live "/sessions/:id", SessionShowLive, :show
  live "/projects", ProjectsLive, :index
  live "/skills", SkillsLive, :index
  live "/tips", TipsLive, :index
  live "/settings", SettingsLive, :index
end
```

- [ ] Commit `feat(router): live routes for 7 tabs`.

## Task 9.3: ECharts hook

**Files:**
- Create: `assets/js/hooks/echarts_hook.js`
- Create: `priv/echarts/echarts.min.js` (copy from Python project)
- Modify: `assets/js/app.js`

- [ ] Hook initializes ECharts on `mounted()`, reads option JSON from `data-option`, re-renders on `updated()` if dataset id changed.

```js
import * as echarts from "../vendor/echarts.min.js"

export default {
  mounted() { this.chart = echarts.init(this.el); this.render() },
  updated() { this.render() },
  destroyed() { this.chart && this.chart.dispose() },
  render() {
    const opt = JSON.parse(this.el.dataset.option)
    this.chart.setOption(opt)
  }
}
```

- [ ] Register in `app.js`: `Hooks: { ECharts }`.
- [ ] Test via `Phoenix.LiveViewTest`: assert element with `phx-hook="ECharts"` rendered.
- [ ] Commit `feat(ui): ECharts hook + vendor`.

## Task 9.4: `OverviewLive`

**Renders:** all-time totals, today, 7-day, daily token chart, top projects, top tools, top models.

- [ ] LiveView mount: subscribe to `"scanner"` topic; load `Analytics.Overview.totals()`, `Daily.series()`, `Projects.summary()`, `Tools.breakdown()`, `ByModel.breakdown()`.
- [ ] `handle_info({:scan_complete, _}, socket)` reloads and pushes patch.
- [ ] LiveView test: mount, assert tokens rendered, simulate `send(self(), {:scan_complete, …})`, assert reload.
- [ ] Commit `feat(live): overview tab`.

## Task 9.5: `PromptsLive`

- [ ] Sortable table (by input/output/total). Sort applied via `phx-click="sort"`.
- [ ] Pagination via stream + cursor.
- [ ] Click row → `<.link patch={~p"/sessions/#{id}"}>`.
- [ ] Test sort transitions.
- [ ] Commit `feat(live): prompts tab`.

## Task 9.6: `SessionsLive` + `SessionShowLive`

- [ ] List recent sessions (page + filter by project).
- [ ] Drill-down shows turns, prompt + response collapsibles, tool calls.
- [ ] Tests.
- [ ] Commit `feat(live): sessions list + drill-down`.

## Task 9.7: `ProjectsLive`

- [ ] Cards per project with totals + sparkline (ECharts).
- [ ] Test.
- [ ] Commit `feat(live): projects tab`.

## Task 9.8: `SkillsLive`

- [ ] Table of skills with est tokens + invocation count.
- [ ] Test.
- [ ] Commit `feat(live): skills tab`.

## Task 9.9: `TipsLive`

- [ ] List tips with severity badges + dismiss button (`phx-click="dismiss"` → `Tips.dismiss/1` → `assign(:tips, Tips.active())`).
- [ ] LiveView test simulates dismiss.
- [ ] Commit `feat(live): tips tab`.

## Task 9.10: `SettingsLive`

- [ ] Radio buttons for plans (api/pro/max/max-20x).
- [ ] On change → `Pricing.Plan.set/1`. Subscribe to `"plan:changed"`. All other LiveViews subscribed already → cost recalculation propagates.
- [ ] Test.
- [ ] Commit `feat(live): settings tab`.

---

# Phase 10 — CLI

## Task 10.1: `mix dashex.scan`

**Files:**
- Create: `lib/mix/tasks/dashex/scan.ex`

```elixir
defmodule Mix.Tasks.Dashex.Scan do
  use Mix.Task
  @shortdoc "Scan Claude Code JSONL files into local DB"

  def run(_) do
    Mix.Task.run("app.start")
    summary = TokenDashex.Scanner.Worker.tick(TokenDashex.Scanner.Worker)
    IO.puts("Scanned #{summary.files} files, #{summary.records} records.")
  end
end
```

- [ ] Test via `Mix.Task.run/2` smoke test.
- [ ] Commit `feat(cli): mix dashex.scan`.

## Task 10.2: `mix dashex.today` + `mix dashex.stats` + `mix dashex.tips`

- [ ] Each calls into `Analytics`/`Tips` and prints a small ASCII table (use `IO.ANSI` for color).
- [ ] Tests assert output contains expected substrings.
- [ ] Commit `feat(cli): today/stats/tips tasks`.

## Task 10.3: `mix dashex.dashboard`

- [ ] Starts Phoenix endpoint (`Mix.Task.run("phx.server")`) after running scan, opens browser via `:os.cmd('open ...')` (mac) / `xdg-open` / `start`.
- [ ] Flag `--no-scan`, `--no-open` mirroring Python.
- [ ] Commit `feat(cli): mix dashex.dashboard`.

## Task 10.4: Optional `escript` build

- [ ] Add `escript: [main_module: TokenDashex.CLI]` to `mix.exs`.
- [ ] Implement `TokenDashex.CLI.main/1` argv dispatcher reusing Mix tasks logic.
- [ ] Document `mix escript.build` in README.
- [ ] Commit `feat(cli): escript wrapper`.

---

# Phase 11 — Polish & Verification

## Task 11.1: Telemetry events

- [ ] Emit `[:token_dashex, :scanner, :tick]` with `files`, `records`, `duration_ms` measurements.
- [ ] Add to `TokenDashexWeb.Telemetry` summary metrics.
- [ ] Commit `feat(telemetry): scanner metrics`.

## Task 11.2: README rewrite

**Files:**
- Modify: `README.md`

- [ ] Cover: install (Elixir, mix deps.get, mix ecto.setup), `mix dashex.dashboard`, env vars (`CLAUDE_PROJECTS_DIR`, `TOKEN_DASHEX_DB`, `PORT`).
- [ ] Privacy disclaimer (loopback only).
- [ ] Commit `docs: rewrite README for Phoenix`.

## Task 11.3: Migration parity check

- [ ] **Manual:** Run Python `python3 cli.py scan && python3 cli.py stats` on sample `~/.claude/projects/`. Note totals.
- [ ] Run `mix dashex.scan && mix dashex.stats`. Compare totals — must match within rounding tolerance.
- [ ] Document any discrepancies in `docs/PARITY.md`.
- [ ] Commit `docs: parity report Python vs Elixir`.

## Task 11.4: Coverage gate

- [ ] Add `:excoveralls` dep, configure `coveralls.json`, target 85% lib coverage.
- [ ] CI script `mix test --cover`.
- [ ] Commit `chore(test): coverage configuration`.

## Task 11.5: Final smoke test checklist

- [ ] `mix deps.get && mix compile` clean
- [ ] `mix ecto.create && mix ecto.migrate` works on fresh DB
- [ ] `mix test` green, no warnings
- [ ] `mix dashex.dashboard` opens browser, all 7 tabs render
- [ ] Drop a new JSONL into `~/.claude/projects/test_session/` → within 30s LiveView updates without manual refresh
- [ ] Switch plan in Settings → Overview costs recalculate live
- [ ] Dismiss tip → disappears, returns after 14d (verified by clock-mocked test)
- [ ] `git status` clean, all commits descriptive

---

# Self-Review Notes

| Spec area | Covered by |
|-|-|
| JSONL scan + dedup | Phase 4 (4.2–4.6) |
| SQLite schema | Phase 2 (2.1–2.6) |
| 7 dashboard tabs | Phase 9 (9.4–9.10) |
| Pricing engine + plans | Phase 3 (3.2–3.3) |
| Tips (5 rules + dismissal) | Phase 6 (6.1–6.6) |
| Skills catalog | Phase 5 |
| SSE → live updates | Phase 8 + 9.4 |
| CLI (5 commands) | Phase 10 |
| 68 unit tests parity | Phases 2–7 (one test module per Python test file) |
| ECharts charts | Task 9.3 hook |
| Privacy (loopback) | Endpoint `:bind: {127,0,0,1}` already in dev; ensure runtime.exs locks to `127.0.0.1` for prod |
| Env vars | Task 1.3 + 1.5 + Task 11.2 docs |

**Type consistency check:** `Message.id` always `"<session_id>:<message_id>"` everywhere (Tasks 2.1, 4.5). `Tool.message_id` FK matches. `Tips.dismiss/1` arity-1 string everywhere. `Pricing.cost_for/2` (model, usage) consistently.

**Known unimplemented Python features carried as TODO:** project-local `.claude/skills/`, subagent attribution. Documented in `docs/KNOWN_LIMITATIONS.md` (port from upstream).

---

# Estimated Effort

| Phase | Tasks | Rough hours |
|-|-|-|
| 1 Foundation | 3 | 2 |
| 2 DB schema | 6 | 3 |
| 3 Pricing | 3 | 2 |
| 4 Scanner | 7 | 8 |
| 5 Skills | 2 | 2 |
| 6 Tips | 6 | 4 |
| 7 Analytics | 7 | 5 |
| 8 PubSub | 2 | 1 |
| 9 LiveView | 10 | 12 |
| 10 CLI | 4 | 3 |
| 11 Polish | 5 | 3 |
| **Total** | **55 tasks** | **~45 h** |

---

# Execution Handoff

Plan complete. Two execution options:

1. **Subagent-Driven (recommended)** — Fresh subagent per task, two-stage review between tasks, fast iteration. Use `superpowers:subagent-driven-development`.
2. **Inline Execution** — Execute tasks in main session with checkpoints. Use `superpowers:executing-plans`.

**Which approach?**
