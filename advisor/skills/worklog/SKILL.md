---
name: worklog
description: Generate a Jira-ready work log from today's Claude Code sessions across all projects
disable-model-invocation: true
allowed-tools: Bash(python3 *) Bash(bash *) Write
argument-hint: "[date or 'yesterday']"
arguments: [date]
---

Generate a work log by extracting and narrating all Claude Code sessions for the target date.

## Step 0: Preflight

Run `bash ${CLAUDE_SKILL_DIR}/../../scripts/preflight.sh`. Non-zero exit → STOP with its stderr. Set `DOMAIN_PATH` from the `DOMAIN_PATH=` line.

## Step 1: Extract session data

Run the bundled extractor script:

```bash
python3 ${CLAUDE_SKILL_DIR}/../../scripts/extract_sessions.py $date
```

If the output shows `Sessions found: 0`, report "No sessions found for [date]" and stop.

## Step 2: Write the narrative worklog

Using the extracted events, write a **linear narrative** that:

- **Flows chronologically** as a single timeline across all projects
- **Mentions the project name** (bolded) inline when it changes (e.g., "Switched to **example-service**...")
- **Groups into natural phases** with time-of-day headings (e.g., "Morning (10:30-11:15) — Debugging auth flow")
- **Explains the thought process** — not just what was done, but why, and what was learned
- **Calls out pivots explicitly** — when the approach changed: "first tried X, hit problem Y, switched to Z"
- **Is accessible to a junior engineer** — explain decisions, don't assume context

### Output format

```markdown
## Work Log — [Date]

---

### [Time of day] ([HH:MM]-[HH:MM]) — [Phase title]

[2-4 paragraphs narrating what happened: the goal, the approach, any obstacles, what was learned, what was decided]

---

### [Next phase]

...

---

### Where things stand

- [Status or open question]
- [Status or open question]
```

## Step 3: Save the worklog

Write the worklog to `${DOMAIN_PATH}/worklog-[DATE].md` where `[DATE]` is the target date in YYYY-MM-DD format.

## Step 4: Print a summary

After saving, print a brief summary in the conversation:
- Date covered
- Number of sessions found
- Projects touched
- 3-5 bullet overview of what was accomplished
