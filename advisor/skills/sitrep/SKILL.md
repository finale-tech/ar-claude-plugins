---
name: sitrep
description: "Situational report — facts since last time (worklogs, todo scan, board/PR state), no opinion. Run before /advisor:am. The windowed --since mode is invoked by /advisor:next."
allowed-tools: Read Edit Write Grep Bash mcp__plugin_slack_slack__slack_search_public mcp__plugin_slack_slack__slack_search_public_and_private mcp__plugin_slack_slack__slack_read_channel mcp__plugin_slack_slack__slack_read_thread mcp__atlassian__searchJiraIssuesUsingJql mcp__atlassian__getJiraIssue mcp__atlassian__getAccessibleAtlassianResources mcp__github_enterprise__search_pull_requests mcp__github_enterprise__pull_request_read
argument-hint: "[--since <ISO> | --hour | --today] [--domain <name>]"
arguments: [mode]
model: sonnet
effort: high
---

# Situational Report

The facts layer: gather what changed since last time — worklogs, new action items, board/PR/Slack state — and update the tracker. No opinion, no ranking (that is `am`'s job). Fully automatic, no prompts.

## Modes

- **Full** (no `--since`) — the complete sweep below (Steps 0-7): worklogs, todo scan, commitment status, gate, log, rotate. The morning run and the default; run it before `/advisor:am`.
- **Windowed / light** (`--since <ISO>`, sugar `--hour` / `--today`) — invoked by `/advisor:next` each cycle. Do ONLY the following, then STOP:
  1. Resolve the window — `--hour` = now - 60 min; `--today` = local midnight; `--since <ISO>` = as given. Use `date`, never compute by hand.
  2. Preflight (Step 0) to set `DOMAIN_PATH`.
  3. Scan the window following `process.md` — Slack (configured channels/DMs over the window; `slack_read_thread` on every active/🔴 item's thread by `thread_ts` from `.cache/active-threads.txt` or its Source link, since the windowed channel read misses old-parent threads; then `from:@username` + mentions to discover), Jira updated-since, and a live PR-state read on active/🔴 PRs (`protocol.md` → "GitHub access"). Bound every search to the window.
  4. Update the tracker: add genuinely-new items, update factual status/`Updated` on changed ones. Do NOT re-sort the 🔴/🗃️ tables (that is `am`'s ranking).
  5. Print a concise "what changed since <ts>" summary with confidence tags.
  - SKIP worklogs, the coverage gate, the session-log entry, and rotation. **Never write a session-log entry in windowed mode** — it would move `LAST_SESSION_DATE` and make the next full run under-scan.

Everything below (progress map + Steps 0-7) is the **full** mode.

## Config

```
Scripts dir:      ${CLAUDE_SKILL_DIR}/../../scripts
Person:           PERSON_NAME (variants: PERSON_ALIASES) — from Step 0's preflight output; "the user" below
Slack ID:         SLACK_USER_ID — from Step 0
Slack username:   SLACK_USERNAME — from Step 0; used for from:@/to:@ searches (the <@ID> form can return zero)
Transcripts:      ${DOMAIN_PATH}/advisor/status.md → Domain Sources → `meeting-transcripts`
Todos process:    ${CLAUDE_SKILL_DIR}/../../references/process.md
GitHub (github.com): username GITHUB_USERNAME (from Step 0); repos from ${DOMAIN_PATH}/advisor/status.md → "Repos" (one owner/repo per line)
                  Access via `gh` CLI or the GitHub MCP — see `protocol.md` → "GitHub access" for the query contract
Slack channels + DMs: read from ${DOMAIN_PATH}/advisor/status.md → "Slack Sources" (Step 4)
Active threads:   ${DOMAIN_PATH}/advisor/.cache/active-threads.txt   (channel_id→thread_ts per open tracker item; written by gather.sh — Step 4b)
Cache dir:        ${DOMAIN_PATH}/advisor/.cache   (written by gather.sh)
```

## Guardrails

Read `${CLAUDE_SKILL_DIR}/../../references/guardrails.md` and follow it for the whole run. As your first output — before the Step 0 map — print a one-line acknowledgment (do not paste the file).

## Progress map

As you enter each step, advance this map's markers (`[x]` done · `[>]` current · `[ ]` pending · `[-]` skipped — say why) and print the step's one-line summary (guardrail #9). You need not reprint the whole map every step; declaring the current step before acting is how you confirm you are not skipping one.

```
SITREP PROGRESS
[ ] STEP 0  PREFLIGHT
[ ] STEP 1  DATE RANGE
[ ] STEP 2  GATHER (LOCAL SWEEP)
[ ] STEP 3  WORKLOG NARRATIVE
[ ] STEP 4  TODO SCAN (TRANSCRIPTS + SLACK + JIRA + GITHUB)
[ ] STEP 5  COMMITMENT STATUS
[ ] STEP 6  VALIDATE (GATE)
[ ] STEP 7  LOG & SUMMARIZE
```

---

## Step 0 — Preflight (fail-hard)

Run as a single Bash call: `bash ${CLAUDE_SKILL_DIR}/../../scripts/preflight.sh [<domain>]`
`<domain>` is the value after `--domain` in the arguments, if one was given; otherwise run it with **no argument**. `--since`, `--hour` and `--today` are modes, never domains: do not pass them to it.

- Non-zero exit → STOP with the script's stderr as the reason.
- On success set `DOMAIN_PATH` from the `DOMAIN_PATH=` line and `LAST_SESSION_DATE` from the `LAST_SESSION_DATE=` line. Also keep `PERSON_NAME`, `PERSON_ALIASES`, `SLACK_USER_ID`, `SLACK_USERNAME` and `GITHUB_USERNAME` — the Config block and later steps refer to them by name. Announce: **Domain:** `${DOMAIN_PATH}`.

---

## Step 1 — Date range

Use `WINDOW_START_DATE` / `WINDOW_START_EPOCH` from Step 0 — do NOT read `session-log.md` for this (it is append-only and large) and never compute either yourself.

1. Range = **`WINDOW_START_DATE` through today, live through `NOW`**. The start is a **fixed 24-hour overlap buffer**, not a floor: preflight sets it to the *last scan's own timestamp minus 24h* (read from the cache manifest before this run overwrites it), clamped so it never lands later than the day after `LAST_SESSION_DATE` — so a real multi-day gap (a missed day, a cleared cache) is never silently under-scanned for the buffer's sake. The end is the current moment, not midnight, so an ask made earlier today is never left for tomorrow's run.
2. Live-scan window bounds (Step 4's Slack reads): `oldest` = `WINDOW_START_EPOCH`, `latest` = `NOW_EPOCH` — both straight from Step 0, no derivation needed.
3. Announce: **Sitrep covering `WINDOW_START_DATE` — now (`NOW`)** ([N] days) — expect visible overlap with the previous run's covered range; that's the buffer working, not a bug.

---

## Step 2 — Gather (local sweep, run once)

Read `${DOMAIN_PATH}/advisor/status.md` → Domain Sources → the `work-tracker` path (the todo file) and the `meeting-transcripts` folder.

Run as a single Bash call:
`bash ${CLAUDE_SKILL_DIR}/../../scripts/gather.sh sitrep ${DOMAIN_PATH} <start> <end> <work-tracker-path> --names "<PERSON_ALIASES>" --transcripts <meeting-transcripts-path>`
(Leave out `--transcripts` if `status.md` has no `meeting-transcripts` line. If there is no `work-tracker` line, pass `""` for the tracker path.)

- Non-zero exit → STOP with stderr.
- On `GATHER_OK`: note the `manifest:` and `coverage_checklist:` paths. The extractor has run once per day into `${DOMAIN_PATH}/advisor/.cache/sessions-<date>.txt`, and transcript hits are in `.cache/todo-candidates.txt`. Read each cache file at most once. The manifest's `worklog_dates_needed` is the closed worklist for Step 3.

---

## Step 3 — Worklog narrative

Write a worklog for **exactly** the dates in the manifest's `worklog_dates_needed` (active dates with no `worklog-<date>.md` yet, **plus today unconditionally** — today is never "closed" while the range runs through `NOW`, so `gather.sh` always re-includes it even if an earlier-today run already wrote one) — this is the closed worklist. Do not write worklogs for other dates and do not backfill dates outside the range: dates already covered are in `worklog_dates_existing`, and any out-of-range gap is noted in the summary as an anomaly, not chased here. If `worklog_dates_needed` is `none`, say so and continue.

For each date in the list, read its `.cache/sessions-<date>.txt` **once** and write a narrative worklog to `${DOMAIN_PATH}/worklog-<date>.md` — for today, this **overwrites** any earlier-today version with the fuller day's narrative, not appends to it:

- A linear chronological narrative across all projects; bold the project name inline when it changes.
- Group into time-of-day phases (e.g. "Morning (10:30-11:15) — Debugging auth flow").
- Explain the thinking and call out pivots ("tried X, hit Y, switched to Z").

Do not re-run the extractor.

---

## Step 4 — Todo scan (transcripts + Slack)

Load the todo process reference (Config path) and the work-tracker file (once).

**a) Transcripts:** use the candidates in `.cache/todo-candidates.txt` (already gathered). Dedupe against the todo file. `transcript_scan` is already `[x]`.

**b) Slack — read configured sources + active threads, search only to discover (per `process.md`):** read the channel and DM list from `${DOMAIN_PATH}/advisor/status.md` → "Slack Sources". If that section is absent, STOP and tell the user to add it (template in `${CLAUDE_SKILL_DIR}/../../skills/create/templates/advisor/status.md`).
   - **Each configured channel/DM — READ it** over the window (`oldest`/`latest` per Step 1.2 — `latest` is `NOW_EPOCH`, not midnight): `slack_read_channel` for top-level messages + thread metadata, then `slack_read_thread` on every returned thread with a reply in the window, scanning for `<@SLACK_USER_ID>` mentions and the user's own posts. → check off `slack_channels` and `slack_dms`.
   - **Active-thread re-read — READ every open item's thread by `thread_ts`:** read `.cache/active-threads.txt` (written by `gather.sh` from the Slack permalinks on open tracker rows) and `slack_read_thread` on each `(channel_id, thread_ts)`, scanning replies with a `ts` in the window (through `NOW_EPOCH`). A windowed `slack_read_channel` never returns a thread whose parent predates the window, so a long-running escalation thread with fresh replies is caught **only** here — the Slack analogue of `gh pr view` on active PRs. If `.cache/active-threads.txt` is empty, say so and continue. → check off `slack_active_threads`.
   - **Discovery sweep (search):** `slack_search_public_and_private` for `<@SLACK_USER_ID>` and `from:@SLACK_USERNAME`, windowed `after:/before:` (never `on:`; `before:` is date-granularity only, so use tomorrow's date to make sure today is fully included). This finds sources NOT already covered above — flag any new channel/DM to add, and anchor any newly-found active thread to its tracker item so the active-thread re-read picks it up next run. → check off `slack_catchall_sweep`.

   DM search form is `from:@username` / `to:@username` (the `from:<@ID>` form returns zero here). If any Slack read/search errors, STOP — do not silently omit Slack.

**c) Jira (updated in-window):** query the Atlassian MCP per `process.md` → "Jira Search Patterns", scoped to the window — `searchJiraIssuesUsingJql` with `assignee = currentUser() AND updated >= "<start>" ORDER BY updated DESC` (full run: `updated >= -7d`, plus recently-closed `status in (Closed, Done) AND updated >= -7d`), and `getJiraIssue <KEY>` for tickets referenced by active/🔴 items. Land new comments/status changes on the matching tracker items (status + `Updated`, tagged verified-live). → check off `jira_scanned`.

**d) GitHub — discover new review requests (per repo):** read the repos from `${DOMAIN_PATH}/advisor/status.md` → "Repos"; if that section is absent, STOP and tell the user to add it (template in `${CLAUDE_SKILL_DIR}/../../skills/create/templates/advisor/status.md`). For each repo in Config → GitHub, list the open PRs where the user is still a requested reviewer, via whichever route the runtime provides (`protocol.md` → "GitHub access"):
   - `gh` CLI: `gh pr list --repo <owner>/<repo> --state open --search "review-requested:GITHUB_USERNAME" --json number,title,url,author,createdAt`
   - GitHub MCP: `search_pull_requests` with `is:open review-requested:GITHUB_USERNAME repo:<owner>/<repo>`

   Every hit is a review the user owes — add it as a new PR-review item (dedupe by PR URL against Open Items + the Resolved table in step e). This is the only source that catches a reviewer added directly on GitHub with no Slack/Jira ping. If the query errors or is unauthenticated on every available route, STOP — don't silently skip. → check off `github_review_requests`.

**e) Classify, dedupe, resolve, update the todo file** (directly, no prompts):
   - Add new items sorted by date ascending.
   - **On a status change, rewrite — don't append.** Replace the item's Context cell with the new current state per the Context contract (`protocol.md` step 5): one line of state + who's-blocking + next action. Never append an "Update <date>" block, stack prior states, or paste commit hashes / build-manifest-debug IDs / provenance — those live in the linked ticket/PR/worklog.
   - Resolve items in order: checked-off `[x]` entries still in Open Items; **PR-review rows where the user already has an APPROVED review on record, or the PR is merged/closed** — check live per `protocol.md` → "GitHub access" (`gh pr view <N> --repo <owner>/<repo> --json state,mergedAt,reviews`, or the MCP `pull_request_read`), reading `reviews[]` with `submittedAt` rather than a summary field; resolved if merged/closed, or if an APPROVED review by `GITHUB_USERNAME` is on record → move to Resolved with a one-line note; cross-reference the Step 3 worklogs (work described as done → resolved with worklog evidence); Slack follow-ups. A later review re-request, or an approval dismissed by a new push, re-adds the row as fresh on the next scan.
   - → check off `todo_file_updated` once the adds/resolves/status updates are written.
   - **Tracker hygiene:** write only inside `## Open Items`; never add a `Last updated` line, counts, or run narrative above it. The tracker's only preamble is its title; run-state lives in `session-log.md` + `.cache/`.

Check off each box in `.cache/coverage.md` as you complete it (edit the file: `- [ ]` → `- [x]`). A source that is genuinely unreachable after one retry is marked `- [~] <name> — unreachable: <reason>` instead; the gate accepts `[x]` or `[~] …reason`, never a bare `[ ]`.

---

## Step 5 — Commitment status (read-only)

Read `${DOMAIN_PATH}/advisor/commitments.md`. Count active, overdue, and due-within-7-days. Do not modify it.

---

## Step 6 — Validate (gate, fail-hard)

Run as a single Bash call: `bash ${CLAUDE_SKILL_DIR}/../../scripts/validate.sh sitrep ${DOMAIN_PATH}`

- Non-zero exit → a source was left unchecked. STOP, complete the named source, re-check its box, and re-run. Do not proceed on assumption.
- On `SITREP_OK`: continue.

---

## Step 7 — Log & summarize

1. **Append** to `${DOMAIN_PATH}/advisor/session-log.md`:

```
## [TODAY] ([Day]) — Sitrep

**Type:** Sitrep
**Covering:** [start] — [end]

- Worklogs: [N] generated
- Todos: [N] added, [N] resolved, [N] open
- Commitments: [N] active, [N] overdue
```

2. **Rotate the log** (keeps it bounded): `bash ${CLAUDE_SKILL_DIR}/../../scripts/rotate-log.sh ${DOMAIN_PATH}` — run after the append. It archives older entries to `advisor/archive/` and is a no-op once the log is within its window. Note the `ROTATE_OK kept=… archived=…` line; don't stop on it.

3. **Print final summary:**

```
## Sitrep Complete — ready for /advisor:am
- Worklog: [one-line summary or "no sessions"]
- Todos: [N] open ([N] new, [N] resolved)
- Commitments: [N] active, [N] overdue
- New Slack channel/DM found outside config: [list or "none"]
```

$ARGUMENTS
