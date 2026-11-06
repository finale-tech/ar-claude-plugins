# Advisor Status — Portable Snapshot

*This file is the interchange format. Any Claude session can read this file alone to understand the current trajectory in this domain. Updated weekly during the retrospective.*

---
domain: [DOMAIN_IDENTIFIER]
goal: [PRIMARY_GOAL]
updated: [DATE]
phase: [CURRENT_PHASE]
---

## Current Status

- [3-5 bullet summary of where things stand]
- [Include both progress and gaps]
- [Mention what's actively being worked on]

## Active Commitments

- [List active commitments with due dates — summary only]

## Active Patterns (being worked on)

- **[Pattern name]** — [Brief description and current approach]

## Current State

- [Self-reported emotional/energy/motivation state relevant to this domain]

## Trend

- [Period 1]: [Brief state description]

## Cross-Domain Relevance

- [What other advisors should know about this domain's impact]
- [List paths to other domain status files if they exist:]
  - `/path/to/other-domain/advisor/status.md` — [domain name]

---

## Domain Sources

*Optional. Declare external files this domain's advisor should read for supplementary context. Skills that support domain sources (sitrep, AM, standup, sync) check this section.*

- work-tracker: [/path/to/external/tracker.md]
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
