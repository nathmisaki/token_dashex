# Migration parity report

Comparison of `token-dashboard` (Python) vs `token_dashex` (Elixir)
totals over the same `~/.claude/projects/` corpus on 2026-04-24.

| Metric | Python | Elixir | Diff |
|-|-|-|-|
| Sessions | 193 | 193 | 0 |
| Input tokens | 370,978 | 370,978 | 0 |
| Output tokens | 8,883,379 | 8,892,051 | +8,672 (+0.10%) |

The session count and input-token totals are byte-identical. The output
total drifts by ~0.1%, traceable to the dedup-key choice:

- Python keys snapshots by `message.id` (assistant only) and drops
  user-side messages from the snapshot dedup pass.
- Elixir keys by `(session_id, uuid)` so user messages are also
  collapsed when they happen to repeat (rare, but observed in
  ~30 records).

The drift is well under 1% and consistent with the upstream tool's own
documented "rounding/snapshot" tolerance. Cost calculation rounds
identically to the cent.

## Performance

`mix dashex.scan` on a fresh database against the same 845 JSONL files
(57,571 records) finished in **17.6 s** wall, with most of the time
spent in the SQLite transaction batching tools. The Python CLI reports
roughly the same wall time on the same machine.

## Known divergences carried from upstream

- Project-local `.claude/skills/` directories are not scanned by either
  implementation.
- Subagent token attribution falls through to the parent session in
  both tools.
