# Advisor Status — Portable Snapshot

*This file is the interchange format. Any Claude session can read this file alone to understand the current trajectory in this domain. Updated weekly during the retrospective.*

---
domain: {{DOMAIN}}
goal: Close the Senior → Staff gap in the new role
updated: {{TODAY}}
phase: Week 1 — Absorb
start_date: [YYYY-MM-DD — your first day in the role; optional]
---

## Current Status

- New role; the playbook's Week 1 (Absorb) is starting
- "What You Know So Far" in `playbook.md` is not filled in yet: team, architecture, manager expectations
- No commitments yet; the first `/advisor:sitrep` and `/advisor:am` are pending

## Active Commitments

- None yet

## Active Patterns (being worked on)

- **The patterns in `operating-manual.md`** — on watch; none flagged yet

## Current State

- [Fill in during the first AM session]

## Trend

- Week 0: setup

## Cross-Domain Relevance

- None — single domain

---

## You

*Read by every advisor skill to find you in Slack, GitHub and meeting transcripts. Set once; the retro never rewrites this section.*

- name: [Your full name]
- aliases: [Other names or initials people use for you, comma-separated — optional]
- slack_user_id: [Slack member ID, starts with U]
- slack_username: [Your Slack handle]
- github_username: [Your GitHub login]

---

## Domain Sources

*Optional. Declare external files this domain's advisor should read for supplementary context. `sitrep`, `am`, `next` and `standup` read the work tracker; `sitrep` reads the meeting transcripts; `next` reads the tasks root.*

- work-tracker: {{DOMAIN_PATH}}/work-tracker.md
- meeting-transcripts: [/path/to/meetings/folder/]
- tasks-root: [/path/to/tasks/folder/] — where `/advisor:next` runs background workers, one subfolder per task

---

## Repos

*Read by `/advisor:sitrep` to find PRs waiting for your review. One `owner/repo` (github.com) per line.*

- [owner/repo]

---

## Slack Sources

*Read by `/advisor:sitrep` every run. Declare the channels and DMs the todo scan must check. Each entry is a display name plus its Slack ID. The catch-all sweep flags any channel or DM in the results that is not listed here — add it when that happens.*

**Channels:**
- #[channel-name] ([CHANNEL_ID])

**DMs:**
- [Person or group] — [1:1 or group DM] ([DM_ID])

---

## Universal Advisor Schema Reference

Every advisor domain writes a `status.md` with this structure:
- `domain:` — identifies the advisory area
- `updated:` — last update timestamp
- `Current Status` — 3-5 bullet summary
- `Active Patterns` — behavioral patterns being worked on
- `Current State` — self-reported emotional/energy state
- `Cross-Domain Relevance` — what other advisors should know
