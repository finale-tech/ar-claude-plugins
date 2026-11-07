---
name: retro
description: Weekly retrospective — full-cycle review with plan vs actual, commitment audit, pattern analysis, recalibration, and next week planning. Run weekly.
disable-model-invocation: true
allowed-tools: Read Edit Write Bash
---

# Weekly Retrospective

You are running a weekly retrospective session. This is the most comprehensive session type. Follow the protocol precisely.

## Guardrails

Read `${CLAUDE_SKILL_DIR}/../../references/guardrails.md` and follow it: fail-hard on any error, no silent skips, query real state (never infer a ticket/PR status), no compound Bash operators. As your first output, print a one-line acknowledgment.

## Progress map

Reprint at the start of every step with markers updated: `[x]` done · `[>]` current · `[ ]` pending.

```
RETRO PROGRESS
[ ] STEP 0  PREFLIGHT
[ ] STEP 1  LOAD CONTEXT
[ ] STEP 2  RETROSPECTIVE PROTOCOL (4 questions → planning)
[ ] STEP 3  UPDATE ALL FILES
```

## Step 1: Load Context

### Step 1.0: Resolve domain (fail-hard)

Run: `bash ${CLAUDE_SKILL_DIR}/../../scripts/preflight.sh [<domain>]`
`<domain>` is the value after `--domain` in the arguments, if one was given; otherwise run it with no argument.
Non-zero exit → STOP with stderr. On success set `DOMAIN_PATH` from the `DOMAIN_PATH=` line and announce the domain.

### Step 1.1: Load advisor context

1. `${CLAUDE_SKILL_DIR}/../../references/protocol.md` — Read the **Weekly Retrospective** section
2. `${CLAUDE_SKILL_DIR}/../../references/advisor-behavior.md` — Read the behavioral contract

### Step 1.2: Load user context

3. `${DOMAIN_PATH}/advisor/commitments.md` — Full commitment audit
4. `${DOMAIN_PATH}/advisor/session-log.md` — Read all entries from this week
5. `${DOMAIN_PATH}/playbook.md` — Reflection protocol, recalibration signals, current week targets
6. `${DOMAIN_PATH}/operating-manual.md` — Patterns for the week's review, Instincts to potentially add to, Daily Rules as the behavioral reference
7. `${DOMAIN_PATH}/weekly-impact-log.md` — To update
8. `${DOMAIN_PATH}/advisor/status.md` — To update; also check for cross-domain paths and read those status files

## Step 2: Run the Retrospective Protocol

Follow the Weekly Retrospective protocol from `protocol.md` exactly. Guide the user through each section, waiting for their input on the 4 reflection questions:

1. **4-question reflection** (wait for input on each)
2. **Plan vs. actual comparison**
3. **Commitment audit** (close completed, flag overdue, flag 3+ slips)
4. **Avoidance pattern review** across the week
5. **Recalibration signal check** (if playbook has a recalibration table)
6. **Instinct candidate surfacing** — suggest new instincts based on the week
7. **Plan next week** (top 3 priorities, commitment deadlines, relationship targets)

## Step 3: Update ALL Files

1. **Append** retrospective entry to `${DOMAIN_PATH}/advisor/session-log.md`
2. **Update** `${DOMAIN_PATH}/advisor/commitments.md` — close completed, flag overdue, demote items that no longer pass the playbook filter, add new for next week (only items that pass the commitment filter: maps to playbook dimension + external accountability). Batch-promote from work tracker with user confirmation.
3. **Update** `${DOMAIN_PATH}/advisor/status.md` — refresh the portable snapshot (the front matter and the sections above `## You`). Never change `## You`, Domain Sources, Repos or Slack Sources: those are the user's settings.
4. **Append** weekly reflection to `${DOMAIN_PATH}/weekly-impact-log.md`
5. **Append** to the Instincts section of `${DOMAIN_PATH}/operating-manual.md` if the user confirmed new instincts. Each one gets: the self-check question (bold, quotable), the replacement behavior ("Instead of X, an engineer should Y"), the reasoning (the failure mode it prevents), and the source (the situation that produced it)
6. **Remove** a pattern from the Patterns section of `operating-manual.md` only if the user says they've mastered it

## Behavior

Follow ALL rules from `advisor-behavior.md`. This session has a ~30 minute budget. Be thorough but structured.

$ARGUMENTS
