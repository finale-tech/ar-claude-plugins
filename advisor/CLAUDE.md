# Advisor — plugin development guide

Orientation for working on the advisor plugin itself. Packaged as a Claude Code plugin in the `arnaud-plugins` local marketplace (this repo). Advisor tracks goals and commitments, runs daily check-ins with artifact-gap detection and Jira sync, detects behavioral patterns, and runs weekly retros. It is multi-domain (each domain is its own data folder: e.g. work, a side project).

## Two file worlds — don't confuse them

**Plugin files (this repo)** are the skill logic. Reference them from skills with `${CLAUDE_SKILL_DIR}/...`.

**Domain data files (the user's data dir, e.g. `~/advisor-work`)** are the user's content: `commitments.md`, `session-log.md`, `status.md`, `playbook.md`, `daily-ops.md`, `patterns.md`, `instincts.md`, `weekly-impact-log.md`, plus generated `worklog-*.md`, `daily-brief-*.md`, `.cache/` (incl. `next-state.md`), and `archive/`. The external work tracker (path in `status.md` → Domain Sources → `work-tracker`) is the single source of truth for work items. `status.md` also holds that domain's `meeting-transcripts`, `tasks-root`, `## Repos` and Slack Sources. Resolve the data dir at runtime as `DOMAIN_PATH`; never hardcode it. `~/.claude/advisor-domains.json` maps domain names → paths, sets the default, and holds the `person` block (name, aliases, Slack and GitHub IDs) that `preflight.sh` prints for the skills — no skill or script hardcodes an identity.

## Layout

- `skills/` — slash commands: `sitrep`, `am`, `next`, `retro`, `adhoc`, `standup`, `status`, `commitments`, `create`, `help`. All are `disable-model-invocation: true` **except `sitrep`**, which is model-invocable so `next` can call `sitrep --since <ts>`.
- `scripts/` — deterministic mechanics, run via `bash <script>`:
  - `preflight.sh [domain]` — resolve `DOMAIN_PATH`, fail-hard env checks, emit `LAST_SESSION_DATE`.
  - `gather.sh <mode> <DOMAIN_PATH> <start> <end> [worktracker]` — the local sweep into `.cache/` (sessions, todo candidates, manifest, coverage checklist). Used by `sitrep` (full).
  - `next-context.sh <DOMAIN_PATH>` — cheap intraday context for `next`: NOW, worklog + tracker paths, and `.cache/next-state.md` bookkeeping (last-checkin, minutes-since, cycle). No gather, no MCP.
  - `validate.sh <mode> <DOMAIN_PATH> [brief_date]` — the gate. `sitrep`: fails while any coverage box is unchecked. `am`: validates the daily brief is present and complete (no coverage gate — `am` reads, doesn't gather). `next`: `cycle <sig>` fails if the intraday loop touched `session-log.md` (guards `LAST_SESSION_DATE` drift); `end` fails if the day-wrap entry is missing.
  - `rotate-log.sh <DOMAIN_PATH> [keep]` — keep the last N (default 60) session-log entries, archive the rest to `advisor/archive/session-log-<year>.md`.
- `references/` — `protocol.md` (per-session processing logic), `advisor-behavior.md` (behavioral contract), `guardrails.md` (run rules for sitrep/am), `artifact-rule.md`, `jira-templates.md`, `domain-resolution.md`.
- `agents/domain-builder.md` — interview agent for `/advisor:create`.
- `skills/create/references/` — templates that scaffold a new domain's data files.

## How the layers flow

- **`sitrep` (facts):** preflight → `gather.sh` (once, into `.cache/`) → model does the MCP scan (Slack + Jira + PRs) per `process.md`, checking off `.cache/coverage.md` → `validate.sh sitrep` gate → worklogs + tracker updates → log & `rotate-log.sh`. `--since <ts>` is a windowed light scan (no worklogs/gate/log) that `next` invokes.
- **`am` (coach):** preflight → reads `sitrep`'s worklog + tracker (no gather) → ranks urgency (regenerates 🔴/🗃️) + Artifact Rule → writes the daily brief → `validate.sh am` (brief-only) → interact → optional Jira sync.
- **`next` (PM):** preflight → `next-context.sh` (captures a `session-log` fingerprint) → `sitrep --since <last-checkin>` → pulse + notify → tracker + `.cache/next-state.md` writes → `validate.sh next … cycle` guard (fail-hard if the cycle touched `session-log.md`). Session-log entry only at `end`, gated by `validate.sh next … end`.

The `sitrep` and `am` SKILL.md files reprint a progress map at each step.

## Design rules — keep these when editing

- **Scripts own the mechanics; skills call them and trust the exit code.** Keep deterministic work (domain resolution, extraction, counts, validation, rotation) in scripts, not prose steps.
- **Fail hard, no silent skips.** A failed script or unreachable source stops the run with a named reason. Never present incomplete output as complete.
- **Coverage gate.** Every source a run must touch is a checkbox in `.cache/coverage.md`; `validate.sh` blocks until all are checked. Add a box when you add a source.
- **Query real state, never infer.** PR/ticket/approval status comes from a live query (`gh`, Jira MCP), not from worklog wording. Never merge two identities.
- **No compound Bash** (`&&`/`||`) — one command per call; use `git -C <path>` for other dirs.
- **Compose via scripts and shared references.** One exception: `next` invokes `sitrep --since <ts>` (which is why `sitrep` is model-invocable). `am` does not gather — it reads what `sitrep` produced. The scan definition lives once in `process.md`, run at `full` (sitrep) or `--since` (next) scope.
- **Bounded reads.** Get the last session date from `LAST_SESSION_DATE`; never read the whole `session-log.md` for a date. Rotation keeps that file small.

## Gotchas

- **`allowed-tools` must list every MCP tool a skill calls** (e.g. `mcp__plugin_slack_slack__*`). An omitted tool fails silently — the source looks handled but returns nothing.
- **MCP tool names are runtime-specific, and a name that doesn't resolve fails silently too.** The names in `allowed-tools` are the Claude Code ones (`mcp__atlassian__*`, `mcp__plugin_slack_slack__*`). Other runtimes expose the same servers under different names — Cowork uses per-connector identifiers (`mcp__<connector-id>__slack_read_channel`), and has no `gh` binary at all, so GitHub goes through `mcp__github_enterprise__*`. When running a skill somewhere other than Claude Code, map the names to that runtime's before trusting a source as covered; `protocol.md` → "GitHub access" states the GitHub contract independently of the tool.
- **Slack channels/DMs live in the domain's `status.md` → "Slack Sources"**, not in the skill. The catch-all sweep flags new ones to add there.
- **Bundled deps:** the session extractor is `scripts/extract_sessions.py` (used by `gather.sh` and the `worklog` skill); the todo-mining patterns are in `references/process.md`. Scripts find both relative to their own folder.
- **Dates:** never compute in your head; run `date`.

## Editing and testing

- This repo is the `arnaud-plugins` local marketplace. After edits, reload so a running session picks them up: restart Claude Code or `/plugin marketplace update arnaud-plugins`.
- Scripts take env overrides — `ADVISOR_CONFIG`, `ADVISOR_EXTRACT_SCRIPT`, `ADVISOR_TODOS_PROCESS` — and `gather.sh` / `spawn-worker.sh` take the transcripts and tasks folders as arguments, so you can fixture-test them without touching real data or `~/.claude`. Run `bash -n` on every script.
- Verify a change end-to-end with a live `/advisor:sitrep` then `/advisor:am`: look for the progress map, the script tokens (`PREFLIGHT_OK`, `GATHER_OK`, `SITREP_OK`, `BRIEF_OK`, `ROTATE_OK`), a populated `.cache/`, and `archive/`.
- Skills invoke scripts via `bash <script>`, so an execute bit is not required; keep scripts `chmod +x` for consistency.
