---
name: help
description: Full system overview — what the advisor does, how the workflow fits together, and all available commands.
disable-model-invocation: true
---

# Advisor — Personal Advisory System

A framework-based coaching system that tracks commitments, keeps you on task, detects behavioral patterns, and holds you accountable. It works for any domain — each one is its own data folder (for example your job, or a side project).

Three layers, each doing one job: `sitrep` gathers the **facts**, `am` is the **coach**, `next` is the intraday **PM**. Every recommendation traces back to your specific situation, patterns, and commitments — never generic advice.

## Workflow

### Daily — facts, then coaching

**`/advisor:sitrep`** (~5 min) — the situational report: what changed since last time. Generates worklogs, scans transcripts + Slack + Jira/PRs for new/updated items, and refreshes your work tracker. Facts only, no opinion. Always runs on Sonnet at high effort. Run this first.

**`/advisor:am`** (~15 min) — the coach. Reads `sitrep`'s facts (does not re-gather), then: decides urgency (regenerates the 🔴/🗃️ tables), applies the Artifact Rule to catch gaps, holds accountability on commitment↔ticket contradictions, sets today's top 3, and syncs Jira (posts on approval). Writes the daily brief. Run after `sitrep`. `skip-sync` skips the Jira sync.

### Intraday — the PM loop

**`/advisor:next start`** — start the intraday PM loop (`am` offers it each morning). It checks in on a timer and winds itself down at 5pm. Each check-in has a subagent run `/advisor:sitrep --since <last check-in>` (Slack, Jira, PRs), reads your tasks' worker status, tells you what changed, and suggests the next move with context ("I checked X, it looks deployed; next is Y, should I hand that to a worker?"). On your yes it hands the work to a background Claude worker in the task's folder (`<tasks-root>/<task>/`, with `tasks-root` set in `status.md`): `claude attach <id>` opens it in any terminal tab. Report-only (it never posts), WIP limit of 3, and nothing goes to a worker without your yes. `--local` skips the broad scan; `end` stops the loop and wraps the day.

### On-Demand

**`/advisor:adhoc <situation>`** — bring a decision, a bad interaction, a draft message, a reaction. The advisor names the relevant framework and produces actionable output — a script, a plan, or "no action needed" with reasoning.

**`/advisor:standup`** — a team-facing standup message (Yesterday / Today / Blockers) from your log, commitments, and tracker. Read-only.

**`/advisor:worklog [date | yesterday]`** — write a narrative worklog for one day from your Claude Code sessions (sitrep does this automatically for the days it covers).

### Weekly

**`/advisor:retro`** (~30 min) — 4-question reflection, plan vs. actual, commitment audit (close / flag / escalate 3+ slips), pattern review, instinct surfacing, next-week planning.

### Read-only views

**`/advisor:status`** — current portable snapshot. **`/advisor:commitments`** — what's due today / overdue / upcoming.

## All Commands

```
/advisor:help                    — This overview
                                   All commands accept --domain <name> to target a non-default domain
/advisor:create                  — Set up a new advisor domain (interactive interview)
/advisor:sitrep                  — Situational report (facts since last time). Full mode.
/advisor:sitrep --since <ISO>    — Windowed light scan (used by /advisor:next; also --hour / --today)
/advisor:am                      — Daily coaching over sitrep's facts (accountability, urgency, artifact sync, priorities)
/advisor:am skip-sync            — Coaching without the Jira sync phase
/advisor:next start              — Start the intraday PM loop (on a timer, ends at 5pm; hands work to background workers)
/advisor:next                    — One check-in (the loop's timer runs this). --local skips the broad scan
/advisor:next end                — Stop the loop, wrap the day
/advisor:retro                   — Weekly retrospective
/advisor:adhoc <situation>       — Event-driven coaching
/advisor:standup                 — Team-facing standup message (read-only)
/advisor:worklog [date]          — Narrative worklog for one day from your Claude Code sessions
/advisor:status                  — Current snapshot (read-only)
/advisor:commitments             — What's due and overdue (read-only)
```

## Data Architecture

The advisor resolves your domain directory from `~/.claude/advisor-domains.json`. Use `--domain <name>` to target a specific domain, or omit it for the default.

**Your files:**
- `playbook.md` — strategic plan and execution roadmap
- `daily-ops.md` — daily operating manual and trigger/response scripts
- `patterns.md` — avoidance patterns with detection heuristics
- `instincts.md` — communication instincts (living document)
- `catchup.md` — recovery sprint plan (when active)
- `weekly-impact-log.md` — cumulative impact tracker
- `worklog-YYYY-MM-DD.md` — daily activity narrative (written by `sitrep`)

**The tracker (single source of truth for work items):**
- Your work tracker (path set in `status.md` → Domain Sources → `work-tracker`) — 🔴 / 🗃️ tables, statuses, who's-waiting, `Logged` + `Updated` timestamps. `sitrep` adds/resolves, `next` updates status/active-3, `am` ranks (regenerates the tables).

**Advisor-managed files** (in `advisor/`):
- `commitments.md` — formal commitment tracker with IDs, due dates, slip counts
- `session-log.md` — session history + deliberation record (append-only, rotated)
- `status.md` — portable snapshot + the domain's sources: Domain Sources (`work-tracker`, `meeting-transcripts`, `tasks-root`), `## Repos` (one `owner/repo` per line), Slack Sources
- `daily-brief-YYYY-MM-DD.md` — `am`'s coaching brief (opinion layer over the facts)
- `.cache/next-state.md` — `next` loop bookkeeping (loop on/off, timer id, active-3 with worker ids, pending suggestion, notified)

## Getting Started

1. Create a directory for your domain and run `/advisor:create` (registers it automatically, and asks for your name and Slack/GitHub IDs the first time).
2. Each morning: `/advisor:sitrep` then `/advisor:am`.
3. Through the day: say yes when `am` offers the loop (or run `/advisor:next start`). For check-ins that run without you at the keyboard, add the allow rules in `references/protocol.md` → "Unattended setup".
4. Weekly: `/advisor:retro`.

## Config file and multiple domains

`~/.claude/advisor-domains.json` holds who you are and where your domains live. `/advisor:create` writes it; to edit it by hand:

```json
{
  "person": {
    "name": "Jane Doe",
    "aliases": ["Jane", "J.D."],
    "slack_user_id": "U01ABCDEF",
    "slack_username": "jdoe",
    "github_username": "jdoe"
  },
  "default": "work",
  "domains": {
    "work": { "path": "/Users/you/advisor-work" },
    "side-project": { "path": "/Users/you/advisor-side" }
  }
}
```

- `person` is required: `name`, `slack_user_id`, `slack_username`, `github_username`. `aliases` (optional) are the names matched in transcripts and Slack; the default is your first name.
- Use `--domain side-project` with any skill to target a non-default domain.

$ARGUMENTS
