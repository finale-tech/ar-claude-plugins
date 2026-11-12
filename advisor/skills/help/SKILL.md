---
name: help
description: Full system overview — what the advisor does, how the workflow fits together, and all available commands.
disable-model-invocation: true
---

# Advisor — Personal Advisory System

A framework-based career coaching system that tracks commitments, keeps you on task, detects behavioral patterns, and holds you accountable. Your data lives in one private folder per domain, `~/.advisor/<name>/`, which `/advisor:create` sets up from the plugin's starter templates.

Three layers, each doing one job: `sitrep` gathers the **facts**, `am` is the **coach**, `next` is the intraday **PM**. Every recommendation traces back to a named entry in the library or in your own files, applied to your specific situation, patterns, and commitments — never generic advice.

Three parts hold it together: the **engine** (these commands), the **library** (the general plan, shipped with the plugin), and your **data folder** (everything about you).

## Workflow

### Daily — facts, then coaching

**`/advisor:sitrep`** (~5 min) — the situational report: what changed since last time. Generates worklogs, scans transcripts + Slack + Jira/PRs for new/updated items, and refreshes your work tracker. Facts only, no opinion. Always runs on Sonnet at high effort. Run this first.

**`/advisor:am`** (~15 min) — the coach. Reads `sitrep`'s facts (does not re-gather), then: decides urgency (regenerates the 🔴/🗃️ tables), applies the Artifact Rule to catch gaps, holds accountability on commitment↔ticket contradictions, sets today's top 3, and drafts the Jira updates for you to apply (it never writes to Jira itself). Writes the daily brief. Run after `sitrep`. `skip-sync` skips the Jira drafts.

### Intraday — the PM loop

**`/advisor:next start`** — start the intraday PM loop (`am` offers it each morning). It checks in on a timer and winds itself down at 5pm. Each check-in has a subagent run `/advisor:sitrep --since <last check-in>` (Slack, Jira, PRs), reads your tasks' worker status, tells you what changed, and suggests the next move with context ("I checked X, it looks deployed; next is Y, should I hand that to a worker?"). On your yes it hands the work to a background Claude worker in the task's folder (`<tasks-root>/<task>/`, with `tasks-root` set in `status.md`): `claude attach <id>` opens it in any terminal tab. Report-only (it never posts), WIP limit of 3, and nothing goes to a worker without your yes. `--local` skips the broad scan; `end` stops the loop and wraps the day.

### On-Demand

**`/advisor:adhoc <situation>`** — bring a decision, a bad interaction, a draft message, a reaction. The advisor names the relevant framework and produces actionable output — a script, a plan, or "no action needed" with reasoning.

**`/advisor:standup`** — a team-facing standup message (Yesterday / Today / Blockers) from yesterday's worklog, your log, commitments, and tracker. Read-only.

### Weekly

**`/advisor:retro`** (~30 min) — 4-question reflection, plan vs. actual, commitment audit (close / flag / escalate 3+ slips), pattern review, instinct surfacing, next-week planning.

### Read-only views

**`/advisor:commitments`** — what's due today / overdue / upcoming.

## All Commands

```
/advisor:help                    — This overview
                                   All commands accept --domain <name> when you have more than one domain
/advisor:create <name>           — Set up a domain in ~/.advisor/<name>/: scaffold it from the starter templates, or adopt a folder already there
/advisor:sitrep                  — Situational report (facts since last time). Full mode.
/advisor:sitrep --since <ISO>    — Windowed light scan (used by /advisor:next; also --hour / --today)
/advisor:am                      — Daily coaching over sitrep's facts (accountability, urgency, Jira drafts, priorities)
/advisor:am skip-sync            — Coaching without the Jira drafts
/advisor:next start              — Start the intraday PM loop (on a timer, ends at 5pm; hands work to background workers)
/advisor:next                    — One check-in (the loop's timer runs this). --local skips the broad scan
/advisor:next end                — Stop the loop, wrap the day
/advisor:retro                   — Weekly retrospective
/advisor:adhoc <situation>       — Event-driven coaching
/advisor:standup                 — Team-facing standup message (read-only)
/advisor:commitments             — What's due and overdue (read-only)
```

## Data Architecture

Each domain is one private folder, `~/.advisor/<name>/`. With a single domain every skill finds it on its own; with more than one, pass `--domain <name>`.

**The library** (in the plugin, shared by every domain, updated with the plugin):
- `library/playbook.md` — the general plan: the gap to close, the week-by-week plan, reflection and recalibration
- Skills read it through `scripts/library.sh`: `index` lists every section in one line, `show "<name>"` prints one in full. It is never copied into your folder. The same script's `mine` prints your own manual by section (`patterns --active` for the ones being checked).

**Your files:**
- `playbook.md` — your context for the plan: "What You Know So Far" (fill it in as you learn) and your relationship map
- `operating-manual.md` — your whole manual, every entry written in full: the patterns you are working on (`*Status: active*`, `later`, or `mastered` once you've beaten one — `am` and `next` check the active ones), your instincts with their `*Source:*` story, and your daily rules and don'ts. Every skill stops if a heading here carries no text
- `weekly-impact-log.md` — cumulative impact tracker
- `worklog-YYYY-MM-DD.md` — daily activity narrative (written by `sitrep`)

**The tracker (single source of truth for work items):**
- Your work tracker (path set in `status.md` → Domain Sources → `work-tracker`) — 🔴 / 🗃️ tables, statuses, who's-waiting, `Logged` + `Updated` timestamps. `sitrep` adds/resolves, `next` updates status/active-3, `am` ranks (regenerates the tables).

**Advisor-managed files** (in `advisor/`):
- `commitments.md` — formal commitment tracker with IDs, due dates, slip counts
- `session-log.md` — session history + deliberation record (append-only, rotated)
- `status.md` — portable snapshot, plus everything you set once: `start_date` (your first day in the role, so the advisor knows which week you are in), `## You` (who you are), Domain Sources (`work-tracker`, `meeting-transcripts`, `tasks-root`), `## Repos` (one `owner/repo` per line), Slack Sources
- `daily-brief-YYYY-MM-DD.md` — `am`'s coaching brief (opinion layer over the facts)
- `.cache/next-state.md` — `next` loop bookkeeping (loop on/off, timer id, active-3 with worker ids, pending suggestion, notified)

## Getting Started

1. Run `/advisor:create <name>`. It creates `~/.advisor/<name>/` from the starter templates, or adopts a folder you already placed there (nothing overwritten, missing files added), and asks for your name, Slack/GitHub IDs and your start date in the role — only the ones still unset.
2. Fill in `advisor/status.md` → Domain Sources, Repos and Slack Sources. The work tracker is already scaffolded as `work-tracker.md` in your folder; point `work-tracker` elsewhere if you keep one already.
3. Each morning: `/advisor:sitrep` then `/advisor:am`.
4. Through the day: say yes when `am` offers the loop (or run `/advisor:next start`). For check-ins that run without you at the keyboard, add the allow rules in `references/protocol.md` → "Unattended setup".
5. Weekly: `/advisor:retro`.

## Who you are

The `## You` section of `advisor/status.md` tells the scans who to look for. `/advisor:create` fills it in; to edit it by hand:

```
## You

- name: Jane Doe
- aliases: Jane, J.D.
- slack_user_id: U01ABCDEF
- slack_username: jdoe
- github_username: jdoe
```

`name`, `slack_user_id`, `slack_username` and `github_username` are required, and every skill stops with the missing field's name until they're set. `aliases` (optional) are the names matched in transcripts and Slack; the default is your first name.

$ARGUMENTS
