---
name: standup
description: Generate a short standup update from your advisor data. Read-only — no file updates.
disable-model-invocation: true
allowed-tools: Read
---

# Generate Standup

You are generating a team-facing standup message. This is read-only — do not update any files.

## Step 1: Load Context

### Step 1.0: Resolve domain

Read `${CLAUDE_SKILL_DIR}/../../references/domain-resolution.md` and follow its instructions to set `DOMAIN_PATH`.

### Step 1.1: Load user context

1. `${DOMAIN_PATH}/advisor/session-log.md` — Read the last 1-2 entries
2. `${DOMAIN_PATH}/advisor/commitments.md` — What's active, due, or overdue?
3. `${DOMAIN_PATH}/advisor/status.md` — If a "Domain Sources" section exists with a `work-tracker` path, read that file for context enrichment (PR links, Jira tickets, meeting references).

## Step 2: Generate Standup

From the session log, commitments, and work tracker context (if available), produce a standup in this format. When the work tracker provides richer detail (PR numbers, Jira tickets), use it to make items more specific.

**Report only what a source explicitly marks done — never infer completion.** This message goes to your team; an item belongs under "Yesterday" only if the session log or a commitment records it as completed. If status is unclear, put it under "Today" (in progress), not "Yesterday."

**Yesterday:**
- [Completed items pulled from session log entries and commitment completions]

**Today:**
- [Active priorities and commitments due today]

**Blockers:**
- [Overdue commitments or flagged blockers, or "None"]

## Tone

- Team-facing: factual, concise, no coaching language
- Use work-appropriate framing — translate advisor concepts (commitments, patterns) into standard work items
- Keep it short — 3-5 bullets total across all sections

$ARGUMENTS
