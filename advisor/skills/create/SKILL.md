---
name: create
description: Set up a new advisor domain — creates the private data folder ~/.advisor/<name>/ from the starter templates and records who you are. Run once per domain.
disable-model-invocation: true
argument-hint: [domain name]
allowed-tools: Read Edit Bash(bash *)
---

# Create an Advisor Domain

Sets up the private data folder `~/.advisor/<name>/` from the plugin's starter templates (`templates/` next to this file). Nothing is generated: the templates are copied as they are, with the domain name, today's date and the folder's own path filled in. The templates are blank forms; the general plan stays in the plugin's `library/` and is never copied.

## Step 1: Name the domain

Use the name in the arguments if one was given. Otherwise ask for a short name: lowercase letters, digits and dashes (for example `career`).

## Step 2: Create the folder

Run: `bash ${CLAUDE_SKILL_DIR}/../../scripts/create-domain.sh <name>`

Non-zero exit → STOP and show stderr (the script refuses to overwrite an existing folder). On success, set `DOMAIN_PATH` from the `DOMAIN_PATH=` line.

## Step 3: Record who you are

Ask for these five in one message:

1. **Full name**
2. **Aliases** — other names or initials people use for you in meetings and Slack (optional; the default is your first name)
3. **Slack member ID** — in Slack, open your profile, then **⋮**, then **Copy member ID** (it starts with `U`)
4. **Slack handle**
5. **GitHub login** — `gh api user -q .login` prints it

Write the answers into the `## You` section of `${DOMAIN_PATH}/advisor/status.md`, replacing each field's `[placeholder]` (keep the aliases placeholder if none were given). Change only those five lines.

Then run `bash ${CLAUDE_SKILL_DIR}/../../scripts/preflight.sh <name>`. It must end with `PREFLIGHT_OK`; if it fails, fix the field it names.

## Step 4: Say what's left

> Domain `<name>` is ready at `<DOMAIN_PATH>`. Before the first `/advisor:sitrep`, fill in `advisor/status.md` → Domain Sources, Repos and Slack Sources, and set `start_date` there if you want the advisor to know which week of the role you are in. Fill in `playbook.md` → "What You Know So Far" as you learn it. The plan comes from the plugin's library. `operating-manual.md` starts empty and is all yours: write the patterns you are working on, your instincts and your own rules in full; `retro` adds to it as the weeks go by.

$ARGUMENTS
