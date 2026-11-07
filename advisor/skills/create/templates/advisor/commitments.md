# Commitment Tracker

*Domain: {{DOMAIN}} | Updated: {{TODAY}}*

*The advisor reads this at every AM session and flags anything due or overdue.*

---

## Active Commitments

| ID | Commitment | Made | Due | Status | Source | Context |
|----|------------|------|-----|--------|--------|---------|

## Completed

| ID | Commitment | Made | Completed | Notes |
|----|------------|------|-----------|-------|

## Overdue / Slipped

| ID | Commitment | Made | Original Due | Slip Count | Notes |
|----|------------|------|--------------|------------|-------|

---

## How Commitments Work

- **Created:** During any session, always with a specific due date.
- **Tracked:** AM session checks what's due today, what was completed, and what slipped. If a domain source (work tracker) is configured in `advisor/status.md`, AM also surfaces untracked items.
- **Completed:** Moved to the Completed table with the completion date.
- **Slipped:** Moved to the Overdue table. Slip count tracks repeat deferrals — triggers pattern discussion at 3+.
- **Context:** Optional brief reference — a link, PR number, or one-liner tying the commitment to its source material. Populated manually or during a session.
- **IDs:** Sequential ({{PREFIX}}-001, {{PREFIX}}-002, ...). Never reused.
- **Next ID:** {{PREFIX}}-001
