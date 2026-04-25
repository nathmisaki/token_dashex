# token_dashex

Local-first dashboard for Claude Code token usage. Reads JSONL session
recordings from `~/.claude/projects`, persists them in a single SQLite
database, and serves a live dashboard with Phoenix LiveView.

This is a port of the upstream Python
[`token-dashboard`](https://github.com/anthropics/) to Elixir/Phoenix 1.8 +
LiveView 1.1, with feature parity across all seven tabs (Overview, Prompts,
Sessions, Projects, Skills, Tips, Settings).

## Quick start

```bash
mix deps.get
mix ecto.migrate
mix dashex.dashboard
```

The dashboard opens at <http://127.0.0.1:4000>. The first launch may take
a few seconds to ingest existing JSONL files; subsequent launches are
incremental.

## CLI tasks

| Task | Purpose |
|-|-|
| `mix dashex.scan` | One-shot scan + ingest |
| `mix dashex.stats` | Print all-time totals + cost |
| `mix dashex.today` | Print today's window |
| `mix dashex.tips` | Print active tips |
| `mix dashex.dashboard` | Scan + start LiveView dashboard + open browser |

`mix dashex.dashboard` accepts `--no-scan` and `--no-open`.

## Configuration

Environment variables (all optional):

| Var | Default | Purpose |
|-|-|-|
| `CLAUDE_PROJECTS_DIR` | `~/.claude/projects` | Where to look for JSONL |
| `TOKEN_DASHEX_DB` | `~/.claude/token-dashex.db` | SQLite database path (prod only) |
| `PORT` | `4000` | HTTP port |

In production releases the database lives under `~/.claude/`, the same
location as the upstream Python tool. The two databases have different
filenames so they can coexist.

## Privacy

Everything runs on `127.0.0.1`. No network calls are made for your
data — pricing rates ship as a static `priv/pricing.json`. JSONL files
are read-only; the dashboard never writes back to Claude Code's session
recordings.

## Architecture

```
┌─ ~/.claude/projects/*.jsonl
│
└─→ Scanner.Worker (GenServer, 30s tick)
        ├─ Parser (pure)
        ├─ Dedup    (collapse streaming snapshots)
        ├─ Walker   (find + slug projects)
        └─ Ingest   (idempotent upsert into SQLite)
                │
                └─→ Phoenix.PubSub broadcast
                        │
                        └─→ LiveView pages re-render
```

* `lib/token_dashex/scanner/` — JSONL pipeline
* `lib/token_dashex/analytics/` — Ecto query layer (overview/prompts/etc.)
* `lib/token_dashex/tips/` — rule-based suggestions (5 rules)
* `lib/token_dashex/skills.ex` — `~/.claude/` skill catalog
* `lib/token_dashex/pricing.ex` — `priv/pricing.json` loader + cost engine
* `lib/token_dashex_web/live/` — seven dashboard tabs

## Development

```bash
mix test                    # full suite
mix dashex.scan             # one-shot scan
iex -S mix phx.server       # interactive shell
```

The scanner runs in a `GenServer` with a 30-second tick by default. To
disable the periodic scan (e.g. in tests):

```elixir
config :token_dashex, scanner_auto_tick: false
```

## Migration parity

This Elixir build aims for 1:1 parity with the upstream Python tool. Known
divergences:

* Skills scanned only under `~/.claude/{skills,scheduled-tasks,plugins}` —
  project-local `.claude/skills/` directories aren't reachable by either
  implementation today.
* SQLite schema is fresh (`~/.claude/token-dashex.db`), not shared with
  the Python tool's `~/.claude/token-dashboard.db`.

## License

MIT.
