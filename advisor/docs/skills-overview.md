# Advisor — skills & scripts inventory

The current shape after the redesign. Three layers: `sitrep` (facts) → `am` (coach) → `next` (PM), over one tracker and one scan definition (`process.md`, run at `full` or `--since` scope).

## Skills

| Skill | Role | Input | Output |
|---|---|---|---|
| `sitrep` | Facts. Situational report since last time. `--since <ts>` = windowed light (for `next`). Always runs on Sonnet at high effort (`model`/`effort` in its frontmatter). | preflight; `process.md` scan (Slack/Jira/PR + transcripts) | worklogs, tracker updates, session-log entry (full only) |
| `am` | Coach. Reads sitrep's facts, ranks urgency, artifact gaps, accountability, top 3, Jira sync. Does not gather. | sitrep's worklog + tracker + commitments + frameworks | daily brief, updated commitments + session-log, regenerated 🔴/🗃️ |
| `next` | PM. Self-running intraday loop (on a timer, ends at 5pm; interval is `INTERVAL_MIN` in `next-context.sh`): a subagent runs `sitrep --since` each check-in, it reads worker status, suggests the next move with context, and on your yes hands work to background Claude workers. Report-only. | `next-context.sh`; worker `STATUS.md`; scan subagent's summary; tracker; patterns | tracker updates, `.cache/next-state.md`; session-log at `end` only |
| `retro` | Weekly full-cycle review. | commitments, week's log, playbook, patterns | retro entry, updated commitments/status/impact-log |
| `adhoc` | Event-driven coaching. | a situation + frameworks | ad-hoc log entry; commitments if confirmed |
| `standup` | Team-facing standup (read-only). | log + commitments + tracker | a standup message |
| `status` / `commitments` | Read-only views. | status.md / commitments.md | printed snapshot / due-overdue list |
| `create` / `help` | Domain setup / overview. | interview / none | scaffolded domain / this overview |

All are `disable-model-invocation: true` except `sitrep` (unlocked so `next` can call it) and `next` (unlocked so its own timer, which arrives as plain text in an interactive session, can start a check-in; the description limits it to an exact `/advisor:next` prompt).

## Scripts

| Script | Purpose | In | Out |
|---|---|---|---|
| `preflight.sh` | Resolve domain + fail-hard env checks. | `[domain]` | `DOMAIN_PATH`, `LAST_SESSION_DATE`, `PREFLIGHT_OK` |
| `gather.sh` | Local sweep (session extraction, transcript grep, coverage). Used by `sitrep` full. | `<mode> <DOMAIN_PATH> <start> <end> [tracker]` | `.cache/` files, `GATHER_OK` |
| `next-context.sh` | Cheap intraday context for `next`: time, loop state, 5pm cutoff, live workers + their `STATUS.md`. | `<DOMAIN_PATH>` | NOW, `PAST_CUTOFF`, `LOOP`, `NEXT_JOB_ID`, `WORKER` lines, `NEXT_CONTEXT_OK` |
| `spawn-worker.sh` | Hand a task to a background Claude session: promote single-file task to a folder, append the brief to `TASK.md`, resume the folder's latest conversation or start fresh (`claude --bg`, `manual` permission mode). Refuses (exit 3) if a worker is already live. | `<task-path> <name> <brief-file> [--repo <dir>]` | `WORKER_ID`, `ATTACH`, `SPAWN_WORKER_OK` |
| `append-log.sh` | Append one entry to `session-log.md`, strictly at the end (append mode only; refuses an entry without a `## YYYY-MM-DD` heading). Used by `next end`. | `<DOMAIN_PATH> <entry-file>` | `APPEND_LOG_OK bytes=…` |
| `validate.sh` | The gate. sitrep = coverage; am = brief complete. | `<mode> <DOMAIN_PATH> [brief_date]` | `SITREP_OK` / `BRIEF_OK`, or fail |
| `rotate-log.sh` | Bound the session log; archive overflow. | `<DOMAIN_PATH> [keep]` | `ROTATE_OK kept=… archived=…` |

## Scan engine

`references/process.md` — the one definition of how to scan Slack/Jira/GitHub/transcripts, classify, and write the tracker. Slack uses `from:@username` (not `<@ID>`). Scopes: `full` (7-day, sitrep) and `delta` (`--since`, next). Suspicious-zero self-check + confidence tags (verified-live / inferred / unverified).

## Write lanes on the tracker (the work tracker)

- `sitrep` — adds/resolves items, updates factual status.
- `next` — updates status/`Updated`, maintains active-3, appends new items; never re-sorts.
- `am` — regenerates/re-sorts the 🔴/🗃️ tables (urgency); sole owner of ordering.
