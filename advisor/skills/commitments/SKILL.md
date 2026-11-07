---
name: commitments
description: View commitment status — what's due today, what's overdue, and what's coming up in the next 7 days.
disable-model-invocation: true
allowed-tools: Read Bash
---

# Commitment View

Read-only view. Do NOT modify any files.

## Steps

0. Run `bash ${CLAUDE_SKILL_DIR}/../../scripts/preflight.sh [<domain>]` — `<domain>` is the value after `--domain` in the arguments, if one was given. Non-zero exit → STOP with stderr. Set `DOMAIN_PATH` from the `DOMAIN_PATH=` line.
1. Read `${DOMAIN_PATH}/advisor/commitments.md`
2. Get today's date by running `date '+%Y-%m-%d'` (a separate Bash call). Compute "due today," "overdue" (with day count), and "upcoming (next 7 days)" as day-deltas from that value — never compute dates or day-of-week in your head.

## Output

```
## Commitments — [domain]

**Due today:**
- [list, or "Nothing due today"]

**Overdue:**
- [list with how many days overdue, or "None"]

**Upcoming (next 7 days):**
- [list, or "Nothing upcoming"]

**Total active:** [count]
```

$ARGUMENTS
