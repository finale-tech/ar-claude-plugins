---
name: status
description: View the current portable snapshot — a quick summary of where things stand without running a full session.
disable-model-invocation: true
allowed-tools: Read Bash
---

# Status Snapshot

Read-only view. Do NOT modify any files.

## Steps

0. Read `${CLAUDE_SKILL_DIR}/../../references/domain-resolution.md` and follow its instructions to set `DOMAIN_PATH`.
1. Read `${DOMAIN_PATH}/advisor/status.md`
2. Read `${DOMAIN_PATH}/advisor/commitments.md`. Get today's date with `date '+%Y-%m-%d'` (a separate Bash call) and count active and overdue as day-deltas from it — never compute dates in your head.

## Output

```
## Advisor Status — [domain from status.md]
**Updated:** [date] | **Active commitments:** [N] | **Overdue:** [N]

[Contents of the Current Status section from status.md]

**Active patterns:** [list from status.md]

**Current state:** [emotional/energy state from status.md]
```

If cross-domain paths are listed in status.md, mention them but do NOT read them for this view.

$ARGUMENTS
