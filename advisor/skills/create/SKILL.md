---
name: create
description: Set up an advisor domain — scaffolds the private data folder ~/.advisor/<name>/ from the starter templates, or adopts a folder you already put there, and records who you are. Run once per domain on each machine.
disable-model-invocation: true
argument-hint: [domain name]
allowed-tools: Read Edit Bash(bash *)
---

# Create an Advisor Domain

Sets up `~/.advisor/<name>/`, the private data folder, one step at a time. Two starting points, both handled by the script:

- **Nothing there yet.** The folder is built from the plugin's starter templates (`templates/` next to this file). Nothing is generated: the templates are copied as they are, with the domain name, today's date and the folder's own path filled in.
- **A folder is already there** — a domain copied from another machine, or restored. Nothing in it is overwritten. The script adds only what the templates have and the folder lacks, and the identity step then fills in whatever is still a placeholder.

Either way the general plan stays in the plugin's `library/` and is never copied.

Walk the user through the steps below in order. At each step say what was found and what happens next, in one or two lines. On any non-zero exit, STOP and show the script's stderr.

## Step 1: Name the domain

Use the name in the arguments if one was given. Otherwise ask for a short name: lowercase letters, digits and dashes (for example `career`).

## Step 2: Build or adopt the folder

Run: `bash ${CLAUDE_SKILL_DIR}/../../scripts/create-domain.sh <name>`

Non-zero exit → STOP and show stderr (a path that exists but is not a domain is refused, so is a bad name). On success, set `DOMAIN_PATH` from the `DOMAIN_PATH=` line and read `CREATE_MODE`:

- `new` → say: "Created `<DOMAIN_PATH>` from the starter templates."
- `adopted` → say: "Found an existing domain at `<DOMAIN_PATH>`. Nothing in it was changed, except what was missing: <the `ADDED=` list>." If `ADDED=none`, say nothing was missing.

## Step 3: Record who you are

Read `${DOMAIN_PATH}/advisor/status.md`. Six fields can still be unset: the five under `## You` and `start_date:` in the front matter. A field is unset when it is blank or still holds its `[placeholder]`. List the unset ones and ask for exactly those, in one message. If none are unset, say so and go to Step 4.

1. **Full name**
2. **Aliases** — other names or initials people use for you in meetings and Slack (optional; the default is your first name)
3. **Slack member ID** — in Slack, open your profile, then **⋮**, then **Copy member ID** (it starts with `U`)
4. **Slack handle**
5. **GitHub login** — `gh api user -q .login` prints it
6. **Start date** — your first day in the role, as `YYYY-MM-DD`. The plan is indexed by week, and this is how the advisor knows which week you are in (optional: leave it blank if the domain is not a new role)

On a machine without Slack or GitHub access (a personal laptop, say), `none` is a valid answer for fields 3 to 5: only the `sitrep` scans use them, and those do not run there. Preflight requires the fields to be set, not to be real.

Write answers 1–5 into the `## You` section of `${DOMAIN_PATH}/advisor/status.md`, replacing each field's `[placeholder]` (keep the aliases placeholder if none were given), and answer 6 into the `start_date:` line of the front matter at the top of the same file (keep its placeholder if none was given). Change only the lines that were unset.

Then run `bash ${CLAUDE_SKILL_DIR}/../../scripts/preflight.sh <name>`. It must end with `PREFLIGHT_OK`; if it fails, fix the field it names.

## Step 4: Say what's left

Read the Domain Sources, Repos and Slack Sources sections of `${DOMAIN_PATH}/advisor/status.md` and name the lines that still hold a placeholder. Then:

> Domain `<name>` is ready at `<DOMAIN_PATH>`. Still to fill in `advisor/status.md` before the first `/advisor:sitrep`: <the placeholder lines>. The work tracker is scaffolded at `work-tracker.md`; point `work-tracker` elsewhere if you keep one already. Fill in `playbook.md` → "What You Know So Far" as you learn it. The plan comes from the plugin's library.

For a `new` domain add: `operating-manual.md` starts empty and is all yours: write the patterns you are working on, your instincts and your own rules in full; `retro` adds to it as the weeks go by. For an `adopted` domain, say instead how many patterns, instincts and rules the manual already holds (`bash ${CLAUDE_SKILL_DIR}/../../scripts/library.sh check ${DOMAIN_PATH}` prints the count on its `STEP LIBRARY-CHECK` line).

$ARGUMENTS
