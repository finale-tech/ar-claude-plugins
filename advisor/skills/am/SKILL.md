---
name: am
description: Daily coaching check-in — read sitrep's facts, hold accountability, rank urgency, detect artifact gaps, draft Jira actions for you to apply, set priorities. Run after /advisor:sitrep.
disable-model-invocation: true
allowed-tools: Read Edit Write Grep Bash mcp__atlassian__searchJiraIssuesUsingJql mcp__atlassian__getJiraIssue mcp__atlassian__getAccessibleAtlassianResources mcp__github_enterprise__pull_request_read
argument-hint: "[optional: skip-sync] [--domain <name>]"
arguments: [mode]
---

# Morning Check-in

The coach. Three phases: Read, Interact, Sync. `am` does **not** gather — it reads what `sitrep` produced (worklogs + the freshly-scanned tracker) and layers the coaching on top. Run `/advisor:sitrep` first. Never invoke another advisor skill; the shared work is in the scripts and references.

## Config

```

Scripts dir:  ${CLAUDE_SKILL_DIR}/../../scripts
References:   ${CLAUDE_SKILL_DIR}/../../references
Facts from:   sitrep — worklog-<date>.md + the work-tracker (both refreshed by the morning sitrep)
```

## Guardrails

Read `${CLAUDE_SKILL_DIR}/../../references/guardrails.md` and follow it for the whole run. As your first output — before the Step 0 map — print a one-line acknowledgment (do not paste the file).

## Progress map

As you enter each step, advance the map's markers (`[x]` done · `[>]` current · `[ ]` pending · `[-]` skipped — say why) and print the step's one-line summary (guardrail #9); you need not reprint the whole map every step.

```
AM PROGRESS
[ ] STEP 0  PREFLIGHT
[ ] STEP 1  LOAD CONTEXT
[ ] STEP 2  READ SITREP FACTS
[ ] STEP 3  BOARD STATE (FROM TRACKER)
[ ] STEP 4  BUILD DAILY BRIEF
[ ] STEP 5  VALIDATE (GATE)
[ ] STEP 6  INTERACT — ACCOUNTABILITY & PRIORITIES
[ ] STEP 7  SYNC — ARTIFACT GAPS   (skipped if skip-sync)
[ ] STEP 8  OFFER THE INTRADAY LOOP
```

---

## Phase 1: Read — build the daily brief

### Step 0 — Preflight (fail-hard)

Run: `bash ${CLAUDE_SKILL_DIR}/../../scripts/preflight.sh --require-fresh-tracker [<domain>]`
`<domain>` is the value after `--domain` in the arguments, if one was given; otherwise pass no domain. `skip-sync` is a mode, never a domain: do not pass it to preflight. `--require-fresh-tracker` makes preflight exit non-zero when `session-log.md` has no `Sitrep` entry dated today — i.e. this morning's `sitrep` did not run — so the dependency is a deterministic gate, not a judgment call. Non-zero exit → STOP with stderr (its message names the fix). On success set `DOMAIN_PATH` from the `DOMAIN_PATH=` line and announce the domain.

### Step 1 — Load context

Reference files:
1. `${CLAUDE_SKILL_DIR}/../../references/protocol.md` — the **AM Session** section
2. `${CLAUDE_SKILL_DIR}/../../references/advisor-behavior.md`
3. `${CLAUDE_SKILL_DIR}/../../references/artifact-rule.md`
4. `${CLAUDE_SKILL_DIR}/../../references/jira-templates.md`

User files:
5. `${DOMAIN_PATH}/advisor/commitments.md` — due today / overdue
6. `${DOMAIN_PATH}/advisor/session-log.md` — last 2-3 entries
7. `${DOMAIN_PATH}/catchup.md` if it exists, else `${DOMAIN_PATH}/playbook.md`
8. `${DOMAIN_PATH}/patterns.md`
9. `${DOMAIN_PATH}/advisor/status.md` — the `work-tracker` path under Domain Sources, plus any Cross-Domain Relevance status files.

### Step 2 — Read sitrep's facts (do not gather)

`am` reads; it never runs `gather.sh` or extracts sessions — `sitrep` already did.
1. Take `TODAY` and `YESTERDAY` from Step 0's preflight output — do not shell out for them and never compute a date yourself.
2. Read the work-tracker (path from status.md). Preflight has already confirmed it was updated today (deterministic gate — no need to re-judge freshness here); treat it as this morning's `sitrep` facts.
3. Read yesterday's worklog `${DOMAIN_PATH}/worklog-<yesterday>.md` (and today's if present) for the recap. If absent, note "no worklog — recap from tracker only."

### Step 3 — Board state (from the tracker)

The tracker already carries current ticket/PR status (scanned by the morning `sitrep`, tagged verified-live). Use it as the board state — do NOT re-run the full board sweep.
- For a commitment whose linked ticket is NOT represented on the tracker, do a targeted `getJiraIssue <KEY>` to confirm its status for accountability (call `getAccessibleAtlassianResources` first if you lack the cloud ID).
- If Atlassian is unreachable, note it and proceed with the tracker's statuses (mark them unverified rather than STOP).

### Step 4 — Build the daily brief

Follow `protocol.md` Phase 1 processing. Key rules (per guardrails — query real state, never infer):
- **Todo pre-filter:** before calling any item an artifact gap, check the tracker for a RESOLVED entry (match PR number / ticket ID / description). If resolved, mark **Covered** and skip the Artifact Rule for it.
- **GitHub review state:** for any "pending draft" item, verify live per `protocol.md` → "GitHub access" — count the PR's reviews in state `PENDING`, via `gh pr view <N> --repo <owner>/<repo> --json reviews --jq '[.reviews[] | select(.state=="PENDING")] | length'` (separate Bash call) or the GitHub MCP `pull_request_read`. 0 → **Covered (submitted)**; >0 → **Gap: draft not submitted**. Never infer submission from worklog wording.
- Apply the Artifact Rule to each work item >30 min not pre-filtered. Cross-reference commitments ↔ tickets.
- **Decide urgency:** regenerate the work-tracker urgency tables in place (🔴 Overdue/Due-soon + 🗃️ Needs Prioritization) per `protocol.md` step 5 — this ranking is `am`'s job; never invent a due date. Write only inside `## Open Items`; never add a `Last updated` line or run narrative above it.

Write `${DOMAIN_PATH}/advisor/daily-brief-<TODAY>.md` (today's date via `date '+%Y-%m-%d'`) in the `protocol.md` format.

### Step 5 — Validate (gate, fail-hard)

Run: `bash ${CLAUDE_SKILL_DIR}/../../scripts/validate.sh am ${DOMAIN_PATH} <TODAY>`

Non-zero exit → the brief is missing a section. STOP, fix it, re-run. On `BRIEF_OK` continue to Phase 2.

---

## Phase 2: Interact — accountability & priorities

Follow `protocol.md` AM Phase 2, using the daily brief as the data source. **Two turns, hard gate: ask first, conclude second — never in one pass.**

**Turn 1 — ask, then STOP.** Ask only the load-bearing questions: the ones whose answer would change an ordering or a recommendation (e.g. "C-030 says delivered but PROJ-6632 is still open — which is right?"; "did the release cut today?"). Draw them from the **Commitment ↔ Jira Sync** section and any decision the day's ranking hinges on. Never re-ask a fact the sitrep already established. 3-5 sharp questions max. Then **stop and wait for the answers** — do NOT print the ranking, the wrap-up, or a "Start here" in this turn.

**Turn 2 — conclude (only after the answers).** With the answers in hand: flag artifact gaps as Pattern #7 / last-mile delivery gap; apply the `${DOMAIN_PATH}/playbook.md` commitment filter (surface only untracked items mapping to a playbook dimension, 1-2 candidates); then produce the Phase-2 wrap-up from `protocol.md` — bulleted and linked: **🔴 Due today/soon**, **Unresolved from today's AM session**, **Active commitments**, and **🗃️ Needs Prioritization (7 to triage now)** each with a named decision + a **Start here** pick. No emotional check-in. If a load-bearing question went unanswered, tag each dependent pick "assumes <X>" rather than presenting it as settled.

After: **append** a session entry to `${DOMAIN_PATH}/advisor/session-log.md` and **update** `${DOMAIN_PATH}/advisor/commitments.md` for any status changes. Then keep the log bounded: `bash ${CLAUDE_SKILL_DIR}/../../scripts/rotate-log.sh ${DOMAIN_PATH}` (archives older entries; no-op once within the window — don't stop on its `ROTATE_OK` line).

---

## Phase 3: Artifact gaps — draft, you apply (report-only)

If `skip-sync` was passed, mark Step 7 `[-]` and stop after Phase 2.

`am` cannot write to Jira — the Jira write tools are not in its `allowed-tools`, so the runtime makes a write impossible here. `am` drafts each action; you apply the ones you want. Follow `protocol.md` Phase 3:
1. Read Proposed Actions from the brief. If none: "No artifact gaps detected. Board is current." and stop.
2. If more than 4, present the top 3-4 by visibility impact; mention deferred ones.
3. Draft each action with `jira-templates.md` — the ticket key, the field/transition, and the exact comment or body text — ready to paste. Do not attempt the write.
4. Present them as a numbered list; you apply the ones you want in the Jira UI.
5. Update the brief's Proposed Actions to note which you said you'd apply.

---

## Phase 4: Offer the intraday loop

Last step, after Phase 3 (or after Phase 2 if `skip-sync`). Ask one yes/no question: "Start the intraday loop? `/advisor:next` checks in on a timer until 5pm, suggests the next move on your top items, and can hand work to background workers." Offer it only on a weekday and only if it is before 17:00. If `.cache/next-state.md` already shows today's `loop: on`, say it is already running and skip the offer.

`am` does not start the loop itself — on a yes, tell the user to run `/advisor:next start` (that skill owns the scheduling). Mark Step 8 `[x]`, or `[-]` with the reason if the offer was skipped.

$ARGUMENTS
