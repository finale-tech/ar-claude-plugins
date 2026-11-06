# Advisor Session Protocols — Universal Engine

*This file defines the procedural logic each session applies to gathered data. Skills reference specific sections. File paths are relative to `${DOMAIN_PATH}`, the domain directory resolved by `preflight.sh`.*

---

## Execution Rules

Every sitrep and am run follows `references/guardrails.md`. In short: the bundled scripts (`preflight.sh`, `gather.sh`, `validate.sh`) own the deterministic mechanics — domain resolution, session extraction, transcript scanning, the source-coverage checklist, and the validation gate. This file defines the *processing logic* applied to what the scripts gather; it does not re-specify the mechanics. Runs are fail-hard (a script or required source failing stops the run) and gated (a run cannot finish until `validate.sh` confirms every source was covered and the output is complete).

### GitHub access

Guardrail #5 requires PR state to come from a live query. Two routes satisfy that, and a run uses whichever the runtime provides — the `gh` CLI (present under Claude Code) or the GitHub MCP tools (`pull_request_read`, `search_pull_requests`; the route available in Cowork, where there is no `gh` binary). What matters is the *contract*, not the tool:

| Need | Contract |
|---|---|
| Reviews the user owes | open PRs in the configured repos where the user is still a requested reviewer |
| Draft submitted? | count of reviews in state `PENDING` for the PR |
| Review row resolvable? | PR is merged/closed, **or** an `APPROVED` review by the user is on record |

Read the PR's `reviews[]` with their `submittedAt` — never a summary field like `reviewDecision`, which goes stale (guardrail #8). If **neither** route is available, STOP: an unqueryable GitHub is an unreachable source, not a skippable one.

---

## How to Start a Session

Every session skill follows this sequence:

1. Read `./advisor/session-log.md` — last 2-3 entries for continuity
2. Read `./advisor/commitments.md` — what's active, due, or overdue
3. (Optional) Read cross-domain status files listed in `./advisor/status.md` under "Cross-Domain Relevance"
4. Execute the session-specific protocol below

---

## AM Session — Morning Check-in

**Duration:** ~25 minutes (Gather: ~5 min, Interact: ~12 min, Sync: ~8 min)
**Purpose:** Recap yesterday, hold accountability, detect artifact gaps, sync Jira board, set the day's priorities.

The AM session has three phases: Gather, Interact, and Sync.

---

### Phase 1 — Gather

Deep sweep of all available context. Runs before the interactive session begins. Produces the daily brief artifact.

**Sources (read in order):**
1. Take yesterday's date from preflight's `YESTERDAY` (Step 0) — never compute a date yourself.
2. Check for yesterday's worklog file (`./worklog-YYYY-MM-DD.md`). Read it if it exists.
3. Read `./advisor/session-log.md` — last 2-3 entries for continuity.
4. Read `./advisor/commitments.md` — active, due, overdue.
5. Read the work tracker (path from `./advisor/status.md` Domain Sources → `work-tracker`).
6. Read the tracker's ticket/PR statuses (the morning `sitrep` scanned them, tagged verified-live). Do a targeted `getJiraIssue <KEY>` only for a commitment-linked ticket not represented on the tracker. `am` does not run the full board sweep or `gather.sh` — `sitrep` produced these facts.

**Processing:**
1. Build a list of yesterday's work items from the worklog and session log. Deduplicate.
2. **Todo resolution check (pre-filter):** Before classifying any work item as an artifact gap, check if it has a matching RESOLVED entry in the todo file (loaded in Step 1.5 via `./advisor/status.md` work-tracker field). Match on: PR number, ticket ID, or work description substring. If a match is found and the todo status is Resolved/Done, mark the work item as **Covered (resolved in todo tracker)** and skip Artifact Rule evaluation for that item. The todo tracker is the authoritative record for explicitly tracked and closed work.

   **GitHub review state check:** For any work item where a pending draft review was noted (match pattern: "pending draft" + PR number in the work item text or associated todo entry), check the actual GitHub state:
   1. Extract the PR number from the work item text (e.g., "#1124" → 1124)
   2. Find the repo by reading `${DOMAIN_PATH}/pr_reviews/pr_{NUMBER}_review.md` (check first line for a GitHub URL) or from the todo entry
   3. Query the PR's reviews live and count those in state `PENDING`. Either route satisfies this — use whichever is available in the runtime (see "GitHub access" below):
      - `gh` CLI: `gh pr view {NUMBER} --repo {OWNER}/{REPO} --json reviews --jq '[.reviews[] | select(.state == "PENDING")] | length'`
      - GitHub MCP: `pull_request_read` for the PR's reviews, then count `state == "PENDING"`
   4. If the count is 0 → no pending reviews remain → review was submitted → mark as **Covered (review submitted to GitHub)**
   5. If the count is > 0 → draft still pending → mark as **Gap: pending draft not yet submitted**

   This check supersedes text-based inference from worklog language. "Pending draft created" in the worklog means a draft was created, not that it was never submitted.

3. For each work item that took >30 minutes and was not pre-filtered in step 2, apply the Artifact Rule filter (read `artifact-rule.md`):
   - **Covered** — has a Jira ticket (with description), Confluence page, merged PR, or filed bug.
   - **Needs update** — has a ticket but it's stale (no comment update in >3 days) or status is wrong.
   - **Gap** — real effort, no artifact. Propose the right artifact type per the rule.
4. Cross-reference commitments to Jira tickets: which commitments have matching tickets? Which are misaligned (commitment says done but ticket still open, or vice versa)?
5. **Regenerate the work-tracker urgency tables (Option 1 — signal-tiered).** The Open Items are kept as two Markdown tables (columns: `Due | Task | Context / who's waiting | Logged | Link`). Rebuild them in place every morning so they reflect current deadlines and who's-waiting — this is derived state, not hand-maintained, so re-sort don't respect prior manual ordering:
   - **🔴 Overdue / Due-soon** — an item belongs here if ANY of: (a) its text carries an explicit deadline that is overdue or within ~7 days; (b) it maps to a commitment whose due date is overdue or within ~7 days; (c) a named person is actively waiting on the user (a direct ask / re-review / re-approval with activity in roughly the last 10 days). Fill the **Due** cell: the explicit date with a `⚠️` if overdue, `Today (…)` if due today, or `ASAP` for an active-blocker with no explicit date. Order rows most-time-sensitive first: due-today and active (`ASAP`) at the top, then overdue items to verify/close. **Never invent a due date** — if there is no explicit deadline, no linked commitment date, and nobody waiting, the item is NOT 🔴.
   - **🗃️ Needs Prioritization** — every remaining item. **Due** cell = `-`. Sort oldest-logged first (so the most stale surface at the top); items with no logged timestamp at all go at the very bottom, Logged = `-`.

   When moving an item between tables, reorder only — never change its Logged timestamp or Link. The **Context cell follows the Context contract**: it holds only current **state + who's blocking/waiting + next action** (≤ ~2 sentences / 50 words). Rewrite it to the current state on any change; never append an "Update <date>" block or keep prior states. Keep out commit hashes, build/manifest/debug IDs, exact timestamps, and provenance notes ("found via discovery sweep") — those live in the linked ticket/PR/worklog. If an item needs more than the contract allows, put the detail in its detail file and link it.
6. **Needs-Prioritization surfacing:** In the daily brief, list the top few 🗃️ Needs Prioritization items (oldest-logged), plus any that have newly gained a deadline or a waiting stakeholder, and prompt the user to either assign a Due date (which promotes the row into 🔴 next run) or drop it.

**Output:** Write `./advisor/daily-brief-YYYY-MM-DD.md` with these sections:

```
# Daily Brief — YYYY-MM-DD

## Yesterday's Work
| # | Work Item | Time | Source |
|---|-----------|------|--------|
| 1 | [description] | [estimate] | [worklog/session-log/tracker] |

## Artifact Coverage
| # | Work Item | Artifact | Status |
|---|-----------|----------|--------|
| 1 | [description] | [ticket/page/PR or "None"] | [Current / Needs update / Gap] |

## Commitment <> Jira Sync
| Commitment | Jira Ticket | Aligned? |
|------------|-------------|----------|
| [commitment ID + description] | [ticket key or "None"] | [Yes / Stale / Misaligned / No ticket] |

## Jira Board State
- Open tickets: [list]
- Stale (no update >3 days): [list or "none"]
- Missing from board: [untracked work items]

## Needs Prioritization (assign a Due date or drop)
| Work Item | Logged | Note |
|-----------|--------|------|
| [top few oldest-logged items from the 🗃️ Needs Prioritization table] | [logged date or "—"] | [why it may warrant a Due date now, or "no logged date"] |

## Proposed Actions
1. [action type]: [description]
2. ...
```

If no worklog exists for yesterday, note "worklog not available — coverage may be incomplete" in the Yesterday's Work section.

---

### Phase 2 — Interact

The AM accountability and priority-setting flow, reading from the daily brief. **Ask before concluding: the questions (step 1) and the wrap-up (step 4) are two separate turns with a hard gate between them — never produce both in one pass.**

1. **Ask the load-bearing questions, then STOP.** Work through yesterday's commitments and key items, asking only the questions whose answer would change an ordering or a recommendation — use the Commitment <> Jira Sync section for concrete data (e.g., "C-030 says delivered but PROJ-6632 is still open — which is right?"), plus any decision the day's ranking hinges on. Never re-ask a fact the sitrep already established. Specific yes/no or short-answer, 3-5 max. Then **wait for the answers** — do not print the ranking, wrap-up, or "Start here" yet.
   - On slips: check against `./patterns.md` and name the pattern if one matches.
   - Artifact gaps can be flagged as Pattern #7 (analysis expansion) or last-mile delivery gap.
2. **Log brief signals** from the answers.
3. **Surface untracked work (playbook-filtered):** Same filter as before (maps to playbook dimension + external accountability). Now also surfaces artifact gaps as commitment candidates.
4. **Output (only after the step-1 answers):** the end-of-session wrap-up (format below) — bulleted and linked, with the 🗃️ Needs Prioritization section triaging 7 items to a named decision. If a load-bearing question went unanswered, tag each dependent pick "assumes <X>" rather than presenting it as settled. Quick-win artifact gaps can be flagged inline as candidates. Weave any relevant `./daily-ops.md` principle into the interactive discussion rather than the wrap-up.
5. **Append entry to `./advisor/session-log.md`**
6. **Update `./advisor/commitments.md`** if any statuses changed.

### AM Output Format (Phase 2) — end-of-session wrap-up

Deliver the wrap-up as **bulleted lists** (never tables). Link wherever a link exists: each section's source file in its header, and any item that carries a URL in its tracker `Link` field — a PR to its GitHub URL, a ticket to its Jira URL, a "someone's waiting" ask to its Slack permalink. Use `[label](url)` markdown links; plain text only when there is no link.

```
## 🔴 Due today/soon (from [the work tracker](<tracker path>))
- **<ref>** — <one-line status>. *(ASAP | Today (<why>) | ⚠️ N days overdue | due <date>)*
- … one bullet per 🔴 row, most time-sensitive first.

## Unresolved from today's AM session (not yet on the tracker as decisions)
- **<ref>** — <open question raised this session, still unanswered>.
- … or "— nothing left open". Session-scoped: surface them here; do NOT silently fold them into the tracker as decisions.

## Active commitments (from [commitments.md](<path>))
- **<C-ID>** — <description>, due <date>.  (active + overdue only)

## 🗃️ Needs Prioritization (<N> items, no due date) — 7 to triage now
- **<ref>** — <why it warrants a decision now> → **<Do now | Schedule (assign a Due date → promotes to 🔴) | Delegate to <who> | Drop>**.
- … exactly 7 bullets.
- **Start here:** <the single one to pick up first + one line why>.
- *(<N-7> more — full list in [the work tracker](<path>))*
```

Pick the 7 to **help decide**, not just the 7 oldest: weight toward (a) origination / visibility items the Pattern-#4 counter would otherwise bury, (b) anything that just gained a waiting stakeholder, (c) genuine quick wins — then oldest-logged to fill. Each bullet ends with a named decision so the section moves the backlog, and the **Start here** line gives one clear next pick.

---

### Phase 3 — Sync

Present artifact gaps and proposed actions from the daily brief. **Nothing gets written to Jira without explicit user approval.**

**Time budget:** ~8 minutes max. If more than 3-4 actions, prioritize by visibility impact and defer the rest.

1. Read the Proposed Actions from the daily brief.
2. For each proposed action:
   a. State what the action is (create ticket, update comment, change status, flag for Confluence page creation).
   b. Draft the content using the templates from `jira-templates.md`.
   c. Present the draft and **wait for approval**.
   d. On approval, execute the Jira API call using Atlassian MCP tools.
   e. For non-Jira artifacts (Confluence pages, PRs), flag them as manual follow-ups.
3. After all actions are processed, update the daily brief's Proposed Actions section to reflect what was synced.

**Draft format for presenting each action:**

```
### Proposed: [Action type] — [Brief description]

**Ticket:** [New ticket / PROJ-XXXX comment update / status change]

[Drafted content using the appropriate template from jira-templates.md]

**Approve this action? (yes/no/edit)**
```

---

## Intraday Loop — `next`

The tactical PM layer between `am` runs. `next` is a **thin PM**: each check-in it reads *summaries* (worker status, a script snapshot, a scan subagent's summary), names the next move, explains it with enough context to decide, and — on the user's explicit yes — hands the work to a background Claude **worker**. It never does the code work itself and never posts externally. The full step list lives in the `next` skill; this section holds the lifecycle, ranking rubric, suggestion/dispatch rules and the state template.

### Lifecycle — self-running, ends itself

- `next start` runs cycle 1 and sets `loop: on`.
- **Chained one-shot timer.** Every cycle's first step schedules the *next* cycle (`CronCreate`, `recurring: false`, pinned to the `NEXT_CRON` that `next-context.sh` computes, which is where the check-in interval (`INTERVAL_MIN`) is set) and records its id as `next-job-id`. Scheduling first means a failed cycle never breaks the chain.
- **Cutoff.** `next-context.sh` reports `PAST_CUTOFF=yes` from 17:00 local. Then, or when `NEXT_CRON=NONE` (the next fire would land past the cutoff), schedule nothing and run the `end` flow.
- `next end` (manual, or the cutoff): `CronDelete` any pending `next-job-id`, list the workers it started today (never the user's interactive sessions) and offer to `claude stop` the finished ones (stopping keeps the conversation), write the one day-wrap log entry (via `scripts/append-log.sh`, never an `Edit` of the log).
- `am` offers to run `next start` as its last step.

### Unattended setup (allow rules — the user's call; nothing here edits settings)

A timer-fired check-in runs as a system prompt, so the skill's own `allowed-tools` pre-approval does **not** cover it. Without allow rules each fire stalls on a permission prompt (live test: the PM blocked on its first `bash …/preflight.sh`). A stalled session shows as `waitingFor=permission prompt` in the snapshot; the user clears it with `claude attach <id>`. The Slack/Jira/`gh pr` reads the scan uses are already in the user's allow list. To run unattended, add to `permissions.allow` in `settings.json`:

- `Bash(bash <advisor plugin dir>/skills/*/../../scripts/<script>*)` for each of `preflight.sh`, `next-context.sh`, `validate.sh`, `append-log.sh`, `rotate-log.sh`. Write the path in the form the skills actually issue: `${CLAUDE_SKILL_DIR}` is substituted as text, so the command keeps its `skills/<skill>/../../scripts/` segment (live test), and a rule written against the normalized `<plugin dir>/scripts/…` path will likely not match it.
- `Skill(advisor:sitrep)` — the scan subagent
- `Skill(advisor:next)` — the timer-fired check-in. In an interactive session the timer's `/advisor:next` arrives as plain text, not an expanded command (two live observations), so the model loads the skill through the Skill tool; `next` is therefore not `disable-model-invocation`, and its description restricts it to an exact `/advisor:next` prompt.

Deliberately **not** allowed, so they keep prompting: `spawn-worker.sh` (the prompt is a hard second gate on dispatch, beyond the model's own yes-check), `claude stop` (the gate before a worker is stopped), and `osascript -e` (it can run `do shell script`, i.e. arbitrary shell, past the user's deny rules). `claude agents` needs no rule: `next-context.sh` calls it inside the script, so only the outer `bash script` is checked.

### Known hazard — resumed copies share the timer

`claude --resume` of a live session starts a *copy*, and the copy inherits the original's pending timer, so both fire it (live test: one timer fired in both sessions and produced two cycles, each rewriting the same state file). Never resume a PM session while another copy of it is live. `end` cancels timers only in the session it runs in.

### Where the facts come from (keep the PM thread light)

| Fact | Source | Cost to the PM |
|---|---|---|
| time, loop state, worker list, who is stuck | `next-context.sh` (`claude agents --json`) | a few `key=value` lines |
| per-task progress | the worker's `<task>/STATUS.md` (3 lines, in the snapshot) | 3 lines per task |
| "what changed elsewhere" (Slack/Jira/PR) | every check-in, a **subagent** runs `/advisor:sitrep --since <last-checkin>` and returns a tagged summary plus a per-source checklist | a short summary, same cycle |
| real work (code, drafts, investigation) | **workers** | nothing until they report |

Never use `claude logs` as a status source — it is a terminal screen scrape, not readable text. A worker's `STATUS.md` is a *claim*: verify any "done" with one targeted call (PR merged, ticket moved) before marking it shipped. A scan whose checklist is missing a source or shows an error is treated as unverified (no notifications that cycle).

### Ranking — what to do *next* (not a re-sort of the tables)

`am` owns ordering the 🔴/🗃️ tables. `next` only picks the single next action within that order, by tier (highest first):

1. **Someone is waiting on you** — a direct ask / reply owed / re-review / re-approval with a named person, surfaced by the scan.
2. **Overdue commitment or missed self-commitment.**
3. **Last mile** — work at ~90%, small effort to close (drafted-not-posted, one reply, a merge).
4. **Due today.**
5. **Stale >3 days needing a nudge.**

Within a tier, smallest effort-to-ship first — clear the 2-minute loops before the multi-hour ones. Give origination items (the Pattern #4 counter) a visibility bump so pure-execution work never buries them for more than a day. One drift line per cycle, mapped to `patterns.md`.

### `.cache/next-state.md` — loop bookkeeping (not the tracker)

Regenerated each cycle; `Notified` and `Shipped today` are append-only within the day.

```
- date: 2026-07-15
- loop: on
- next-job-id: <CronCreate id of the pending one-shot, or NONE>
- last-checkin: 2026-07-15T14:32-0700
- cycle: 3

## Active (max 3)
1. PROJ-6730 — post progress comment | task-path <tasks-root>/PROJ-6730 | worker 106d779c | repo ~/code/billing-service | started 2026-07-15T14:05-0700 | last-checked 14:32
2. PR #2782 — clear CHANGES_REQUESTED | task-path - | worker - | started 13:30 | last-checked 14:32
3. C-048 design doc — blocked on screenshots | task-path <tasks-root>/design-doc | worker d68d3e73 | started 11:00 | last-checked 14:32

## Pending suggestion
- <one line: what was proposed, to whom, when> | asked 14:32 | unanswered

## Notified
- 2026-07-15T14:32-0700 — PR #2782 approved, waiting to merge

## Shipped today
- (none yet)
```

Track workers by **id** (`claude agents` short id), never by name: Claude auto-renames a session after it starts. `Pending suggestion` is cleared when the user answers.

### Suggestion — the check-in output

One focused suggestion, written as a PM talking to the user, with enough context to decide **before** the question: what you checked, what you found (with how it was verified), the next step, then a yes/no.

```
Task X (PROJ-7245): I just checked — the build is deployed to QA (pipeline green 13:52, verified live). Next step is the verification comment on the ticket plus a ping to the QA lead. Should I hand that to the 7245 worker?
Then: PR #2830 (2 unresolved threads from a reviewer, ~15 min).
```

- If the previous suggestion is still unanswered and nothing changed: one line, `Still pending: <suggestion>?` — do not stack new questions.
- A worker `waiting` on a `permission prompt`: lead with `waiting on you: claude attach <id>`.
- Mark each fact `verified-live <t>` / `inferred` / `unverified` (existing confidence rules).

### Dispatch — only on an explicit yes

Check the worker list first (`WORKER` lines from `next-context.sh`), then:

1. **A worker is already live for the task** (`WORKER_LIVE`, interactive or background) → `SendMessage` it the brief with `notify_when_idle: true`. Never `--resume` a live session: it starts a *copy*.
2. **Otherwise** → write the brief to a temp file and run `scripts/spawn-worker.sh <task-path> <name> <brief-file> --tasks-root <TASKS_ROOT> [--repo <dir>]`. It promotes a single-file task to its own folder (`tasks/foo.md` → `tasks/foo/foo.md`; ask first, and fix links to the old path in the tracker), appends the brief to `TASK.md`, resumes the task folder's newest past conversation if there is one, else starts fresh, and starts the worker in `manual` permission mode (the user's global default is `plan`, which can't edit anything).
3. Print `Worker <name> started (id <id>)`. Attach in any tab: `claude attach <id>`, store the id in Active, and fire a macOS notification only if a worker later needs the user.

Ask for the code repo once per task and remember it (`--add-dir`). The PM never asks a worker to do anything the user's own permissions would block, and never to post to Jira/Slack/GitHub without the user's explicit OK.

### Worker contract

- Home: `<TASKS_ROOT>/<task>/`. `TASK.md` holds the brief(s), newest last.
- When it finishes or gets blocked, the worker overwrites `STATUS.md` with exactly three lines: `done: …`, `blocked: …`, `next: …`.
- `claude attach <id>` opens it in any terminal; `claude stop <id>` ends it and keeps the conversation.

### Write lanes (so `next`, `sitrep`, `am` don't collide)

- `sitrep` — adds/resolves items, updates factual status.
- `next` — updates status/`Updated`, maintains Active (≤3), appends genuinely-new items; never re-sorts.
- `am` — regenerates/re-sorts the 🔴/🗃️ tables (urgency); sole owner of ordering.
- Session log: `next` writes only at `end` (protects `LAST_SESSION_DATE`).

---

## Ad-hoc Session — Event-Driven

**Duration:** Varies
**Purpose:** Apply the right framework to a specific situation and produce actionable output.

### Protocol

1. **Listen first.** Let the user describe the situation fully before responding.
2. **Identify the relevant framework:**
   - Workplace/interpersonal interaction → `./daily-ops.md` trigger/instinct/response scenarios
   - Strategic/career decision → `./playbook.md` strategy and recalibration signals
   - Recovery-phase action → `./catchup.md` priorities (if file exists)
   - Emotional reaction → `./daily-ops.md` three-question framework
   - Behavioral pattern → `./patterns.md`
3. **Apply the framework explicitly:** Name which framework applies and why.
4. **Check for emotional weight:** Is the user reacting to what was said, or what they think was meant? Apply the "most boring explanation" test.
5. **Output:** Specific response script or action plan (not generic advice).
6. **Log any new commitments** in `./advisor/commitments.md`. Before creating, apply the commitment filter: does this map to a playbook dimension AND carry external accountability or credibility cost? If it doesn't pass, it stays in the work tracker only. Always confirm with the user.
7. **Append entry to `./advisor/session-log.md`** with type "ad-hoc" and the topic.

### Ad-hoc Guidelines

- Don't soften the message. If the framework says "let it go," say "let it go."
- If the user is pre-defending or over-explaining in the session itself, name it.
- Provide a specific script when the situation calls for a response to someone.
- If the situation requires no action, say so clearly: "This requires no action. Here's why."

---

## Weekly Retrospective

**Duration:** ~30 minutes
**Purpose:** Full-cycle review — plan vs. actual, commitment audit, pattern analysis, next week planning.

### Protocol

1. **Run the 4-question reflection:**
   - What did I ship or move forward this week?
   - What signals did I receive?
   - What would I do differently?
   - What is my single most important priority for Monday?
   Wait for the user's input on each question before proceeding.

2. **Plan vs. Actual comparison:**
   - Read this week's targets from `./catchup.md` (if exists) or `./playbook.md`
   - Compare against `./advisor/session-log.md` entries for the week
   - Quantify where possible: outputs delivered, commitments completed vs. slipped

3. **Update `./weekly-impact-log.md`:**
   - Add the weekly reflection entry
   - Update relevant sections (outputs, mentoring, design contributions, etc.)

4. **Commitment audit in `./advisor/commitments.md`:**
   - Close all completed commitments (move to Completed table)
   - Flag all overdue commitments (move to Overdue table with notes)
   - If any commitment has slipped 3+ times, trigger a pattern discussion
   - Demote items that no longer pass the playbook filter (move to Demoted table with reason)
   - Create new commitments for next week — only items that pass the commitment filter (maps to playbook dimension + external accountability). Batch-promote from work tracker with user confirmation.

5. **Avoidance pattern review:**
   - Review the week's session logs for any patterns flagged
   - Are patterns recurring, improving, or new?
   - Check against `./patterns.md`

6. **Recalibration signal check** (if `./playbook.md` has a recalibration table):
   - Assess each signal dimension: ahead / on track / behind

7. **Update `./advisor/status.md`:**
   - Refresh the portable snapshot with current state
   - Update emotional state, energy/confidence trend
   - Update cross-domain relevance section

8. **Instinct candidate surfacing** — review the week's patterns and interactions. Suggest any new instincts worth adding to `./instincts.md`. User confirms.

9. **Plan next week:**
   - Top 3 priorities
   - Any commitments with specific deadlines
   - Relationship targets (who to connect with)

10. **If recovery sprint needed**, create or update `./catchup.md`

### Weekly Output Format

```
## Week [N] Retrospective

### Shipped
- [Concrete outputs]

### Signals
- [Explicit and absent signals]

### Plan vs. Actual
| Target | Planned | Actual | Delta |
|--------|---------|--------|-------|
| ...    | ...     | ...    | ...   |

### Commitments
- Completed: [N]
- Slipped: [N] — [reasons]
- New for next week: [list]

### Patterns
- [Recurring/improving/new patterns]

### Recalibration
- [Signal assessment per dimension, if applicable]

### Next Week
1. [Priority 1]
2. [Priority 2]
3. [Priority 3]
```

---

## Advisor Output Rules

*These rules govern how the advisor delivers advice across all session types.*

### Always Show Reasoning and Instincts

Every piece of advice must include:

1. **The advice itself** — the specific script, action, or recommendation
2. **How I got there** — the reasoning chain: what inputs led to this conclusion, what tradeoffs were weighed, what risks were considered
3. **The instinct to build** — a generalizable principle the user can internalize and apply independently in future situations, framed as a self-check question or filter

**Why:** The goal is not to make the user dependent on the advisor. It's to transfer the decision-making framework so they can eventually run these filters themselves in real-time. Advice without reasoning is a fish. Advice with reasoning is fishing lessons.

**Format per advice item:**
```
### [Topic]

**The instinct to build:** [Self-check question or filter to internalize]

**How I got there:** [Reasoning chain — inputs, tradeoffs, risk assessment]

**The general principle:** [One-sentence generalizable rule]
```
