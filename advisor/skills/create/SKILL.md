---
name: create
description: Set up a new advisor domain — creates the private data folder ~/.advisor/<name>/ from the starter templates, takes in an operating manual you already have if you give its path, and records who you are. Run once per domain.
disable-model-invocation: true
argument-hint: [domain name]
allowed-tools: Read Edit Bash(bash *)
---

# Create an Advisor Domain

Sets up the private data folder `~/.advisor/<name>/` from the plugin's starter templates (`templates/` next to this file). Nothing is generated: the templates are copied as they are, with the domain name, today's date and the folder's own path filled in. The templates are blank forms; the general plan stays in the plugin's `library/` and is never copied.

The one file a user may already have is the operating manual: their patterns, instincts and daily rules. If they give its path, the script copies it in as the domain's `operating-manual.md` in place of the empty starter. Everything else is created here.

A domain is created once. If `~/.advisor/<name>/` already exists the script stops and changes nothing.

Walk the user through the steps below in order. At each step say what happened and what comes next, in one or two lines. On any non-zero exit, STOP and show the script's stderr.

## Step 1: Name the domain

Use the name in the arguments if one was given. Otherwise ask for a short name: lowercase letters, digits and dashes (for example `career`).

## Step 2: Ask about an operating manual

Ask one question (in the same message as the name, if the name is also being asked for):

> Do you already have an operating manual — a file with your own patterns, instincts and daily rules — for the advisor to use? If so, give its path. If not, the manual starts empty and you fill it in as you go.

A path means the file is copied; the original stays where it is. No path, or "no", means the starter is used. Do not read, summarise or edit the file yourself, and do not accept any other kind of document in its place: the script checks that the file is a manual.

## Step 3: Create the folder

Run one of:

- no manual: `bash ${CLAUDE_SKILL_DIR}/../../scripts/create-domain.sh <name>`
- with a manual: `bash ${CLAUDE_SKILL_DIR}/../../scripts/create-domain.sh <name> --manual "<path>"` (keep the quotes: a path can hold spaces)

Non-zero exit → STOP and show stderr. Nothing was created. The script stops when the folder already exists, when the name is not valid, and when the manual is missing, fails its check, or has no entries under `## Patterns`, `## Instincts` or `## Daily Rules`. For a manual problem, say what the script named and offer the two ways on: fix the file and run create again, or run create again without it.

On success, set `DOMAIN_PATH` from the `DOMAIN_PATH=` line and read the `MANUAL=` line:

- `MANUAL=starter` → say: "Created `<DOMAIN_PATH>` from the starter templates."
- `MANUAL=imported patterns=<n> instincts=<n> rules=<n>` → say: "Created `<DOMAIN_PATH>` from the starter templates, with your manual in place: <n> patterns, <n> instincts and <n> daily rules the advisor can read. The file you gave is unchanged; the copy in the domain folder is the one the advisor reads from now on, so make later edits there."

## Step 4: Record who you are

Ask for these six in one message:

1. **Full name**
2. **Aliases** — other names or initials people use for you in meetings and Slack (optional; the default is your first name)
3. **Slack member ID** — in Slack, open your profile, then **⋮**, then **Copy member ID** (it starts with `U`)
4. **Slack handle**
5. **GitHub login** — `gh api user -q .login` prints it
6. **Start date** — your first day in the role, as `YYYY-MM-DD`. The plan is indexed by week, and this is how the advisor knows which week you are in (optional: leave it blank if the domain is not a new role)

On a machine without Slack or GitHub access (a personal laptop, say), `none` is a valid answer for fields 3 to 5: only the `sitrep` scans use them, and those do not run there. Preflight requires the fields to be set, not to be real.

Write answers 1–5 into the `## You` section of `${DOMAIN_PATH}/advisor/status.md`, replacing each field's `[placeholder]` (keep the aliases placeholder if none were given), and answer 6 into the `start_date:` line of the front matter at the top of the same file (keep its placeholder if none was given). Change only those six lines.

Then run `bash ${CLAUDE_SKILL_DIR}/../../scripts/preflight.sh <name>`. It must end with `PREFLIGHT_OK`; if it fails, fix the field it names.

## Step 5: Say what's left

> Domain `<name>` is ready at `<DOMAIN_PATH>`. Before the first `/advisor:sitrep`, fill in `advisor/status.md` → Domain Sources, Repos and Slack Sources. The work tracker is scaffolded at `work-tracker.md`; point `work-tracker` elsewhere if you keep one already. Fill in `playbook.md` → "What You Know So Far" as you learn it. The plan comes from the plugin's library.

Then one line about the manual:

- `MANUAL=starter` → `operating-manual.md` starts empty and is all yours: write the patterns you are working on, your instincts and your own rules in full; `retro` adds to it as the weeks go by.
- `MANUAL=imported` → `operating-manual.md` holds what you brought; `retro` adds to it as the weeks go by.

$ARGUMENTS
