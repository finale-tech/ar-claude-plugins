---
name: create
description: Initialize a new advisor domain in the current directory. Conducts a deep probing interview to understand your goal, situation, behavioral patterns, and key relationships, then generates a complete personalized advisory system.
disable-model-invocation: true
context: fork
agent: domain-builder
effort: max
allowed-tools: Read Write Glob AskUserQuestion
---

# Create a New Advisor Domain

You are initializing a new advisor domain in the current working directory.

## Pre-flight Check

First, check if this directory already has advisor data:
- Look for `./advisor/commitments.md` or `./playbook.md`
- If either exists, STOP and tell the user: "This directory already has advisor data. Run `/advisor:am` to start a session, or choose an empty directory."

## Your Task

You are conducting a deep, probing interview to understand this person's goal, situation, and behavioral tendencies. From their answers, you will generate a complete personalized advisory system.

**Read the interview guide** at `${CLAUDE_SKILL_DIR}/references/interview-guide.md` for the full methodology.

**Read the templates** in `${CLAUDE_SKILL_DIR}/references/` to understand the structure of each file you need to generate.

## What You Generate

After the interview, create these files in the current directory:

1. `playbook.md` — Strategic plan based on `${CLAUDE_SKILL_DIR}/references/playbook-template.md`
2. `daily-ops.md` — Behavioral rules based on `${CLAUDE_SKILL_DIR}/references/daily-ops-template.md`
3. `patterns.md` — Diagnosed avoidance patterns (4-6 patterns with detection heuristics)
4. `instincts.md` — Starter communication filters based on `${CLAUDE_SKILL_DIR}/references/instincts-starter.md`
5. `weekly-impact-log.md` — Empty template based on `${CLAUDE_SKILL_DIR}/references/impact-log-template.md`
6. `advisor/commitments.md` — Seeded with first 2-3 commitments based on `${CLAUDE_SKILL_DIR}/references/commitments-template.md`
7. `advisor/session-log.md` — Initialization entry based on `${CLAUDE_SKILL_DIR}/references/session-log-template.md`
8. `advisor/status.md` — Initial snapshot based on `${CLAUDE_SKILL_DIR}/references/status-template.md`
9. `CLAUDE.md` — Local auto-detection file based on `${CLAUDE_SKILL_DIR}/references/claude-md-template.md`

## Register the Domain

After all files are created:

1. Read `~/.claude/advisor-domains.json` (create it if it doesn't exist with `{"default": "", "domains": {}}`)
2. If it has no `person` block (first run), ask the user, one at a time, for: full name; aliases (other names or initials people use for them — optional, default is their first name); Slack user ID; Slack username; GitHub username. Store them as `person` with keys `name`, `aliases` (a list), `slack_user_id`, `slack_username`, `github_username`. Advisor's scans cannot start without them.
3. Ask the user for a short name for this domain (e.g., "work", "side-project")
4. Add the domain to the config: set `domains.<name>.path` to the current working directory (absolute path)
5. If this is the first domain (or `default` is empty), set `default` to this domain's name
6. Write the updated config back to `~/.claude/advisor-domains.json`
7. Tell the user: "Domain '<name>' registered. You can now invoke advisor skills from any directory. Fill in the Domain Sources, Repos and Slack Sources sections of `advisor/status.md` before the first `/advisor:sitrep`."

## Important

- Ask questions ONE AT A TIME. Do not dump all questions at once.
- Adapt follow-up questions based on answers.
- Diagnose avoidance patterns from behavioral signals — don't just ask "what are your patterns."
- After generating all files, show the user a summary of what was created and ask them to review.

$ARGUMENTS
