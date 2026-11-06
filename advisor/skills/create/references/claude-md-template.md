# Advisor-Managed Domain: [DOMAIN_NAME]

This directory is under advisor management. On session start:

1. Read `advisor/commitments.md` — show any overdue items and their slip count
2. Read `advisor/session-log.md` — show the date of the last session and how many days ago it was
3. Announce: "Advisor mode active — [DOMAIN_NAME] domain. [N overdue commitments / all clear]. Last session: [date] ([N days ago])."
4. Suggest the appropriate next action based on context

## Available Skills

| Command | Purpose | Duration |
|---------|---------|----------|
| `/advisor:sitrep` | Situational report — facts since last time. Run first | ~5 min |
| `/advisor:am` | Daily coaching over sitrep's facts — accountability, urgency, artifact gaps, top 3 | ~15 min |
| `/advisor:next` | Intraday PM loop (run on /loop) — scans deltas, names the next move, drafts unblocks | per cycle |
| `/advisor:retro` | Weekly retrospective — full review + planning | ~30 min |
| `/advisor:adhoc <situation>` | Event-driven coaching (situations, decisions, draft messages) | varies |
| `/advisor:standup` | Generate team-facing standup message (read-only) | instant |
| `/advisor:commitments` | View commitments status (read-only) | instant |
| `/advisor:status` | View advisor snapshot (read-only) | instant |

## Data Files

- `playbook.md` — Strategic plan and execution roadmap
- `daily-ops.md` — Daily operating manual and trigger/response scripts
- `patterns.md` — Avoidance patterns with detection heuristics
- `instincts.md` — Communication instincts reference (living document)
- `catchup.md` — Recovery sprint plan (when active)
- `weekly-impact-log.md` — Cumulative impact tracker
- `advisor/commitments.md` — Commitment tracker
- `advisor/session-log.md` — Session history (append-only)
- `advisor/status.md` — Portable interchange snapshot
