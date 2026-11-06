---
name: review-pr
description: Run the full PR-review workflow from a PR link — set up a fresh worktree, gather mandatory Jira/Confluence/KB context, run multi-agent deep review, emit pr_XXXX_review.md + pr_XXXX_comments.json, and print the pr-review-cli create command (never auto-posts). Use when reviewing or re-reviewing a GitHub PR.
allowed-tools: Read, Write, Edit, Bash, Agent, Skill, AskUserQuestion, Glob, Grep, mcp__atlassian__getAccessibleAtlassianResources, mcp__atlassian__getJiraIssue, mcp__atlassian__searchJiraIssuesUsingJql, mcp__atlassian__getConfluencePage, mcp__atlassian__searchConfluenceUsingCql, mcp__atlassian__search, mcp__atlassian__fetch
---

## Config

```
Settings file:   ~/.claude/review-pr.json (read by preflight; see Step 0)
Review dir:      REVIEWS_DIR — from Step 0
Review template: ${CLAUDE_SKILL_DIR}/references/review-template.md
Checks:          ${CLAUDE_SKILL_DIR}/references/pr-review-checks.md, plus EXTRA_CHECKS (user's own, optional) — from Step 0
Local KB:        KB_DIR (optional) — from Step 0
CLI:             CLI — from Step 0 (bundled at ${CLAUDE_SKILL_DIR}/scripts/pr-review-cli)
GH host:         github.com (hardcoded)
Repo folders:    REPO lines — from Step 0
Worktree base:   <repo-root>/.claude/worktrees/
```

---

## Guardrails

These bind every run. As your first output — before the Step 0 progress map — print a one- or two-line acknowledgment summarizing them (do not paste this whole section):

- **GitHub writes:** ONLY via `pr-review-cli`. NEVER use `gh pr review`, `gh pr comment`, `gh pr merge`, `gh pr close`, `gh api` writes, or any other direct GitHub mutation. NEVER pass `--body` to `pr-review-cli`.
- **No compound Bash operators:** NEVER use `&&` or `||` in any Bash command. Each command is its own separate Bash tool call with absolute paths.
- **Read code from the worktree, by path:** NEVER reconstruct file content via `gh pr diff` or `git show`. Read actual files under `<WORKTREE>/` using absolute Read paths and `git -C <WORKTREE>`. Do NOT `cd` the session into the worktree — it stays anchored in its launch directory (see Step 5).
- **Fail hard:** Any mandatory step failure → STOP immediately. Name what failed. No silent skips, no continuing with partial context.
- **Tool-layer enforcement:** the user may also have a `PreToolUse` hook that hard-blocks `pr-review-cli create`/`delete`, `--body`, and `gh` writes. Whether or not it exists, never run them. The user runs the printed command in their own terminal or via `!` in the REPL — both bypass any such hook.

---

## Progress reporting

Keep a visible "you are here" map so both the user and you stay on the sequence. Reprint the map at the start of every step — declaring the current step before acting is how you confirm you are running the steps in order and not skipping any.

Status markers: `[x]` done · `[>]` in progress (current step) · `[ ]` pending · `[-]` skipped (state why).

At the start of each step, print the full map in capitals with markers updated. For example, when entering Step 3:

```
REVIEW-PR PROGRESS
[x] STEP 0    PREFLIGHT
[x] STEP 1    PARSE PR URL
[x] STEP 2    NEW VS RE-REVIEW
[>] STEP 3    PR METADATA AND REVIEW STATE
[ ] STEP 4    NAME SESSION
[ ] STEP 5    CODE SOURCE (WORKTREE)
[ ] STEP 6    MANDATORY CONTEXT — JIRA / CONFLUENCE / KB
[ ] STEP 7    DIFF LINE NUMBERS
[ ] STEP 8    MULTI-AGENT DEEP ANALYSIS
[ ] STEP 9    ARTIFACTS
[ ] STEP 10   PRINT THE COMMAND
[ ] STEP 11   SUMMARY AND FOLLOW-UP
[ ] STEP 12   CLEANUP
```

Print the map as assistant text (not a Bash call). Mark a step `[x]` only after its mandatory actions and any fail-hard checks have completed. If a step is skipped (e.g. Step 9's File C when the PR has no threads), mark it `[-]` and state why.

---

## Step 0 — Preflight (all fail-hard)

Run this skill in default permission mode. It writes files in Step 9; in plan mode Steps 0-8 run read-only and Step 9 stalls, so exit plan mode before starting. If you notice you are in plan mode, say so and ask the user to exit before continuing.

1. **Check Atlassian MCP:** Call `mcp__atlassian__getAccessibleAtlassianResources`. If it errors or returns nothing → STOP with: "Atlassian MCP is not loaded. Connect it (`/mcp`) and re-run this skill." Keep the returned site's `id` as `CLOUD_ID` for Step 6.

2. **Run preflight:** `bash ${CLAUDE_SKILL_DIR}/scripts/preflight.sh`
   - **Exit 2 (`NO_CONFIG=<path>`):** first run. Do the first-time setup below, then re-run preflight.
   - **Any other non-zero exit:** STOP immediately with its stderr as the reason.
   - **Success:** keep `REVIEWS_DIR`, `KB_DIR`, `EXTRA_CHECKS`, `CLI`, and every `REPO <owner/repo>=<path>` line; the last line is `PREFLIGHT_OK`.

### First-time setup (only when preflight printed `NO_CONFIG`)

Ask the user ONE question at a time:

1. **Reviews folder** (required): where review files are saved, e.g. `~/pr-reviews`. If it does not exist, offer to create it with `mkdir -p`.
2. **Notes folder** (optional): a folder of markdown notes to search for context during reviews. Skip if none.
3. **Repos** (optional): for each GitHub repo they review, `owner/repo` and its local checkout folder. Repeat until they say done. Repos not listed here are asked for during Step 5.
4. **Extra checks file** (optional): a markdown file with their own review checks, added to the built-in ones. Skip if none.

Write the answers to the `NO_CONFIG` path as JSON, leaving out skipped keys. Keep `~` as typed; preflight expands it:

```json
{
  "reviews_dir": "~/pr-reviews",
  "kb_dir": "~/notes",
  "repos": { "owner/repo": "~/code/repo" },
  "extra_checks": "~/pr-reviews/checks.md"
}
```

Tell the user the path so they can edit it later, then re-run preflight.

---

## Step 1 — Parse PR URL

From the PR URL argument passed to the skill, extract `OWNER`, `REPO`, and `N` inline:

- Validate that the URL matches `https://github.com/OWNER/REPO/pull/N`. If it doesn't, STOP with: "Invalid PR URL — expected `https://github.com/OWNER/REPO/pull/N`."
- Parse: `OWNER` = path segment 1, `REPO` = path segment 2, `N` = the pull number.
- `gh pr view` in Step 3 validates the extracted values; no further pre-validation is needed here.

---

## Step 2 — New vs re-review

With a single `Glob` call over `REVIEWS_DIR`, match both filename patterns:

- `pr_<N>_review.md` (current)
- `pr-review-<N>.md` (legacy)

If either matches → **re-review mode**: note the path and whether it is the legacy name (Step 9 migrates a legacy file). Otherwise → **fresh review mode**.

State the active mode in one line before proceeding.

---

## Step 3 — PR metadata and review state

Run as a single Bash call:
```
gh pr view <N> --repo <owner>/<repo> --json title,body,headRefName,baseRefName,state,statusCheckRollup,author,files
```

Extract from the output:
- `title` — PR title
- `body` — PR description text
- `headRefName` — the PR branch name (source branch)
- `baseRefName` — target branch (usually `develop`)
- `state` — OPEN / MERGED / CLOSED
- `files` — the changed-file list; use its count for the template's "Files changed: N files" line (no separate `gh pr view` call needed)
- `statusCheckRollup` — CI check states; used immediately below and again for Step 9's CI Status section

**Check CI status (fail-hard).** Scan `statusCheckRollup` for any entry whose state (`state` or `conclusion`, depending on check type) is `FAILURE`. If one or more exist → STOP immediately. List every failing check by name (and its `targetUrl`/`detailsUrl` if present) and tell the user to get CI green — or explicitly re-run/fix the failing check — before re-invoking this skill. Do not proceed to Step 4, and do not spend any further review effort (no worktree, no Jira/Confluence/KB gathering, no agent dispatch). This applies to every failing check regardless of type (build, unit tests, deploy, security scan, etc.) — no exceptions, and no judgment call about whether the failure looks related to this PR's changes.

**Scan for Jira ticket refs.** Search `headRefName`, `title`, and `body` for Jira-style keys: `[A-Z][A-Z0-9]+-[0-9]+` (e.g. `PROJ-1234`), including keys inside `/browse/` URLs in the body. Ignore obvious non-tickets such as `UTF-8` or `SHA-256`.

Record all found ticket refs. If none found, note explicitly.

**Fetch current review state.** Before the deep review, take in the PR's existing reviews (read-only, separate Bash call):
```
gh api repos/<owner>/<repo>/pulls/<N>/reviews
```

Record every review's `state` (APPROVED / CHANGES_REQUESTED / COMMENTED / DISMISSED / PENDING), its author, and submission time. State the current review posture in one line before proceeding — for example an existing APPROVED review, a DISMISSED prior approval, or a PENDING draft. This informs the review (a dismissed approval means a prior sign-off was invalidated) and flags any PENDING draft that Step 10 must reconcile before creating a new one. Do not stop if there are no reviews.

---

## Step 4 — Name the session

Name the session so it is identifiable in `claude --resume` and the sessions list. Build the name from values already resolved in earlier steps:

`pr_review_<repo>_<N>_<jira_id>_<review_nbr>`

- `<repo>` — bare repo name from Step 1 (the segment after `owner/`).
- `<N>` — PR number from Step 1.
- `<jira_id>` — the primary ticket ref from Step 3 (the branch-name ref when several were found). If Step 3 found none, use `noticket`.
- `<review_nbr>` — `1` for a fresh review. For a re-review, count the `## Review History` rows in the file Step 2 located and add 1.

Strip any character outside `[A-Za-z0-9_-]` from each component so the title stays clean. Example: `pr_review_billing-service_482_PROJ-1234_1`.

Rename with the `/rename` command:

```
/rename pr_review_<repo>_<N>_<jira_id>_<review_nbr>
```

Print this line as assistant text for the user to run — do not run it in a Bash call. Naming is not fail-hard: if it is skipped, note it in one line and continue.

---

## Step 5 — Code source (always fresh)

**Determine repo root.** Use the Step 0 `REPO <owner>/<repo>=<path>` line for this repo. If there is none → use AskUserQuestion to get the local path before continuing, and suggest adding it under `repos` in the settings file.

Set:
- `REPO_ROOT` = the resolved local path
- `BRANCH` = `headRefName` from step 3 (if the branch name is longer than 60 characters, use `pr-<N>` as the worktree directory name)
- `WORKTREE` = `<REPO_ROOT>/.claude/worktrees/<BRANCH>`

**Run:** `${CLAUDE_SKILL_DIR}/scripts/setup-worktree.sh <REPO_ROOT> <BRANCH> <N>`

- Exit 0 → parse JSON output: extract `worktree` (store as `WORKTREE`), `branch`, `created` (true/false), `head` (the worktree's current commit), and `updated` (re-review only: whether the refresh moved HEAD). Use the parsed `worktree` path for all subsequent file access.
- **Report it visibly.** Print one line covering created-this-run vs. already-existed, the path, the branch, and `head`. For a pre-existing worktree, say whether it was refreshed or already current — e.g. `Worktree created at <worktree> on <branch>, HEAD <head>`, or `Worktree already existed; refreshed to HEAD <head>`, or `Worktree already existed; already current at HEAD <head>`. This confirms the checkout happened and shows exactly which commit is under review.
- Exit non-zero → STOP with the script's stderr. This includes a pre-existing worktree with uncommitted changes — the script refuses to reset it; report the path and have the user clean or remove it before re-running.

Note: `created:true` means this run created the worktree; `created:false` means the worktree already existed (re-review) and the script has fetched the current PR head and hard-reset the worktree to it (no merge, so no conflicts). Step 12 offers cleanup in both cases.

**Working model — the worktree is the code source, not the session's directory.** Read every changed file and run every git command against the worktree by explicit path: absolute Read paths under `<WORKTREE>/` and `git -C <WORKTREE> …`. Do NOT `cd` the session into the worktree and do NOT relocate it there. The session stays in its launch directory (the primary repo) so its transcript stays under the repo's `~/.claude/projects/` storage; `cd`-ing into the worktree relocates the transcript to the worktree's path, and Step 12's removal would then orphan this session from `claude --resume`. Keeping the session anchored is what lets Step 12 delete the worktree safely.

---

## Step 6 — Mandatory context (all fail-hard where noted)

### a) Jira

If one or more ticket refs were found in step 3:
- For each ticket ref, call `mcp__atlassian__getJiraIssue` with `issueIdOrKey: "<TICKET>"`, `cloudId: CLOUD_ID` (from Step 0), and request the `parent` field so the epic key comes back in this same call. If this call errors → STOP with the error and the ticket ID.
- From the response, extract: summary, description, acceptance criteria, any linked Confluence pages, and the parent epic key from `parent`.
- If a parent epic key is present, run the sibling search now — before Step 7, do not defer it: call `mcp__atlassian__searchJiraIssuesUsingJql` with `jql: "project = <PROJECT> AND 'Epic Link' = <EPIC_KEY> ORDER BY updated DESC"` and `maxResults: 10`. This is lightweight context only, not fail-hard: if it errors or returns nothing, note that and continue. Summarize sibling tickets in a line or two; do not let them expand the review's scope.

If NO ticket ref was found anywhere → warn prominently:

> WARNING: No Jira ticket ref found in branch name, title, or PR body. Continuing without Jira context.

Do NOT stop for a missing ticket.

### b) Confluence

Search for pages related to the ticket and service:
- Call `mcp__atlassian__searchConfluenceUsingCql` with a query such as: `text ~ "<ticket-id>" OR title ~ "<service-name>" AND type = page` (adapt based on what was found — use the repo name as service name if no ticket).
- For any Confluence page URL explicitly linked in the Jira ticket body or PR body, call `mcp__atlassian__getConfluencePage` with that page ID. If an explicitly-linked page fails to fetch → STOP with the URL and error.
- Read the top 2-3 most relevant pages in full.

### c) Local KB

- If `KB_DIR` is `NONE`, say "No local KB configured" in one line and skip to the summary below.
- Glob for `*.md` in `KB_DIR`. If the directory is empty or unreadable → STOP.
- Grep the KB files for: the ticket ID, the `owner/repo` repo name, and 2-3 key terms from the PR title and description.
- Read up to 5 of the best-matching files in full.

**After completing a, b, and c:** Summarize ALL gathered context in 3-5 bullets. This summary is the grounding for every review finding that follows. Do not proceed without writing this summary.

---

## Step 7 — Diff line numbers (source of truth)

Run (single Bash call):
```
python3 <CLI> --host github.com diff <owner>/<repo> <N>
```

Capture the full output. This diff is the ONLY authoritative source for valid line numbers when building the JSON in step 9.

Line-number rules for the JSON (reference these in step 9):
- Line numbers refer to the new (+) side of the diff.
- Use `"side": "RIGHT"` for added or unchanged lines; `"side": "LEFT"` for deleted lines.
- For multi-line ranges, include both `"start_line"` + `"start_side"` and `"line"` + `"side"`.
- For file-level comments (no specific line), use `"subject_type": "file"` and omit `"line"`.

---

## Step 7b — Deterministic pre-scan

Run (single Bash call):
```
${CLAUDE_SKILL_DIR}/scripts/prescan.sh <WORKTREE> <BASE_REF>
```

`<BASE_REF>` is the PR's base branch from step 3. Capture the full output.

The pre-scan finds code shapes that must never be judged by eye — a caught exception reaching
a logging sink, an empty or swallowing catch, an input-bearing parse, an identifier-shaped
argument in a sink call. It does not decide anything. It guarantees these shapes are on the
agenda regardless of how deep any given agent happens to dig, which is what makes round 1
repeatable rather than luck-of-the-draw.

Each hit is a numbered obligation carried into step 8. Exit code is 0 even with hits; a
non-zero exit is a real failure (bad worktree, unresolvable base) — fix it before continuing.

---

## Step 8 — Multi-agent deep analysis

First, read `${CLAUDE_SKILL_DIR}/references/pr-review-checks.md` to load the universal
obligations and the extra check categories. If `EXTRA_CHECKS` is not `NONE`, read that file
too: it holds the user's own checks (for example, rules for their company's logging libraries).

Then invoke the `pr-review-toolkit:review-pr` skill via the Skill tool. Pass, as additional
review aspects: the contents of `pr-review-checks.md` and of `EXTRA_CHECKS`, and the step 7b pre-scan output with
each hit assigned to its owning agent per the ownership table at the end of that document.

Instruct the agents to:

- Read all changed files directly from `<WORKTREE>/` using the Read tool — never use `gh pr diff` or `git show` for file content.
- Ground every finding in the context summary from step 6 (Jira acceptance criteria, Confluence design docs, KB notes).
- **Resolve every assigned pre-scan obligation** to CONFIRMED / CLEARED / UNVERIFIED. An obligation may not be left out of the ledger, and may not be dismissed as a false positive without naming what was read to establish that.
- **Honour the universal obligations (01-05).** In particular 02: never clear a check from a call site or method signature — read the implementation, following into dependency JARs or published sources for the exact version in the diff.
- **Return an evidence ledger** in the 04 table format alongside the findings.
- Flag every finding by severity: **Must resolve** / **Should address** / **Nice to have**.
- When a fix is a direct in-place edit of changed lines, phrase it as a ready-to-apply replacement so Step 9 can post it as a GitHub suggestion.
- Produce structured output: one entry per finding with file path, line reference, severity, title, and explanation.

**Before leaving this step**, verify the returned work is complete against a fixed checklist —
this is the round-1 thoroughness gate:

1. Every pre-scan hit from step 7b appears in some agent's ledger. Count them; the numbers must match.
2. No CLEARED row has an empty or hand-waving evidence cell. Downgrade any that do to UNVERIFIED.
3. Every R1 hit's ledger row names the sink implementation that was actually read, not the call site.
4. Every finding class carries at least one 03 precedent comparison.

If any check fails, send the responsible agent back with the specific gap named. Do not paper
over a gap by writing the missing analysis yourself — the ledger has to reflect what was
actually verified.

**Re-review additions (re-review mode only):**

Before invoking the skill:
1a. Read the prior `pr_<N>_review.md` to extract all previously-raised comments, especially Must resolve and Should address items. Note each one's `[<N>-<n>]` finding ID so Step 9 reuses it rather than renumbering.
1b. Read the prior round's `## Verification Coverage` gaps. Each one is an obligation for this round, ahead of any new analysis — a gap the last round could not settle is the likeliest place for an unfound bug. Carry forward any that remain unresolvable, with the reason updated.
2. Fetch new commits since last review (read-only):
   ```
   gh api repos/<owner>/<repo>/pulls/<N>/commits
   ```
3. For each prior comment, determine its current status: Addressed / Partially addressed / Not addressed / No longer relevant (e.g. file was deleted).

Instruct the review agents to:
- Conduct a full review of all changed files (same depth as a fresh review).
- For each prior Must/Should comment: explicitly state its resolution status and how the author responded.
- Mark delta sections clearly so it is obvious what changed since the last review.

---

## Step 9 — Artifacts

Read `${CLAUDE_SKILL_DIR}/references/review-template.md` to load the exact template shape. Then write the artifacts below to `REVIEWS_DIR`.

**Re-review file handling.** Always render `pr_<N>_review.md` from the template. If Step 2 found only the legacy-named `pr-review-<N>.md`, create `pr_<N>_review.md` fresh from the template and migrate the prior review's content and history into it. Never edit the legacy file or copy it over the new file. If both files are ever present, treat `pr_<N>_review.md` as authoritative. The legacy file is deleted at the end of this step, after validation passes (see Validate artifacts).

**Finding IDs.** Every finding carries a stable ID `[<N>-<n>]` — the PR number, then a flat counter, e.g. `[1155-1]`, `[1155-2]`. Assign it the first time the finding is raised. IDs never change and are never reused; severity and status are attributes that may move round to round, the ID does not. On a re-review, reuse each prior finding's existing ID (read them from the prior review file) and continue the counter from the highest existing ID for new findings — a finding that becomes "No longer relevant" keeps its retired ID. The ID appears in four places: the Finding Index, each finding's markdown header, its Recommended Action bullet, and the prefix of its JSON comment `body`. This lets any GitHub thread be traced back to the review file by searching the tag, in either direction.

**Thread links.** GitHub assigns every review comment a stable id the moment it is created — pending draft comments included — with permalink `<PR_URL>#discussion_r<id>`. Capture them from two read-only sources: live threads on the PR via `gh api repos/<owner>/<repo>/pulls/<N>/comments --paginate` (submitted comments — yours, Copilot's, other reviewers'), and, right after you create a draft, that draft's own comments via `gh api repos/<owner>/<repo>/pulls/<N>/reviews/<REVIEW_ID>/comments --paginate` (pending comments, using the `REVIEW_ID` that `create` returns). Each comment gives `id` (the `r` number), `html_url` (the permalink), `path`, and `line`; thread roots have a null `in_reply_to_id`. Map a root to its finding when its `body` begins with a `[<N>-<n>]` tag — the tag is there because File B posted it. Roots without a tag (Copilot, other reviewers) have no finding but still belong in the thread dashboard (File C). The Thread column is `-` only until the draft is created; Step 10 backfills it as soon as you confirm you posted, and any later re-review refreshes it.

### File A: `pr_<N>_review.md`

Use the template structure. Required sections:

- **Header line:** `# PR #<N> Review: <TICKET> | <title> -- <state>`
- **PR line:** `**PR:** https://github.com/<owner>/<repo>/pull/<N>`
- **Author:** from `gh pr view` output
- **Base branch:** `<headRefName> (merging to <baseRefName>)`
- **Jira:** ticket ID and epic (if found)
- **`**Last updated:**`** today's date
- **`**Last author commit:**`** SHA and message (run `git -C <WORKTREE> log -1 --format='%h (%ad) -- "%s"' --date=short` to get it)
- **`## Finding Index`** — the first `##` section: a table `ID | File:line | Severity | Status | Thread | Title`, one row per finding (open and resolved). This is the scan-and-orient view; keep every row in sync with the finding headers below. Status is Open / Resolved / Partially addressed / No longer relevant. `Thread` is a clickable `[#r<id>](<PR_URL>#discussion_r<id>)` permalink to the finding's posted thread(s), or `-` before posting (see Thread links).
- **`## Context`** — Jira summary + acceptance criteria, relevant Confluence pages, KB notes used in the review
- **`## Review History`** — table with date, commit SHA, and summary of what changed:
  - Fresh review: one row for this review.
  - Re-review: append a new row to the existing table; summarize changes since the prior review and how prior comments were addressed.
- **`## Review Comments`** — grouped by `## File: \`<path>\`` with `### [<N>-<n>] <Severity> — <brief title>` subsections (lead every finding header with its ID). Include line references in the format: `Line <N> / \`ClassName#methodName\``. Always include a suggested fix with before/after code.
- **`## Verification Coverage`** — the audit trail for how thorough this round actually was, so a later round can tell what was checked from what was assumed. Two parts:
  - A one-line tally: `<n> pre-scan obligations — <n> confirmed, <n> cleared with evidence, <n> unverified`.
  - **Verification gaps:** every UNVERIFIED ledger row, as `<obligation> — blocked on <what would settle it>`. Write `None` when the round has none. An empty or omitted section is not the same as `None` and fails validation.

  Keep the full ledger out of this file — only the tally and the gaps belong here. Gaps are for the reviewer's next round, not for the PR author, so nothing in this section becomes a GitHub comment unless it is also raised as a finding.
- **`## Resolved Issues`** — for re-review: move fully-addressed items here (with commit SHA that resolved them).
- **`## CI Status (as of <date>)`** — populate from the `statusCheckRollup` field in step 3 output.
- **`## Strengths`** — concrete observations about what the PR does well.
- **`## Recommended Action`** — subsections: Must resolve before merge / Should address / Nice to have / CI / Overall Assessment. Prefix each action bullet with the finding's ID, e.g. `[1155-3] …`.

### File B: `pr_<N>_comments.json`

Include only findings that map to specific diff lines from step 7. Start every `body` with the finding's `[<N>-<n>]` ID tag so the posted GitHub thread traces back to the review file. Use this shape:

```json
[
  {"path": "src/Foo.java", "line": 42, "side": "RIGHT", "body": "[1155-1] Concise comment text."},
  {"path": "src/Bar.java", "start_line": 10, "line": 15, "start_side": "RIGHT", "side": "RIGHT", "body": "[1155-2] Multi-line range comment."},
  {"path": "src/Baz.java", "subject_type": "file", "body": "[1155-3] File-level note."}
]
```

Architectural or cross-file observations that do not map to a single diff line go in the markdown ONLY — not in the JSON. Keep JSON `body` values concise (ID tag included); the full explanation belongs in the markdown.

**Suggestion blocks.** When a finding's fix is a literal in-place replacement of the exact line(s) the comment is anchored to, put it in a GitHub `suggestion` block so the author can apply it with one click. In the JSON `body`, after the tag and a one-line explanation, add the fenced block (embedded as `\n` in the string). Align the comment's `line` (and `start_line` for a range) to the exact lines being replaced, `side: RIGHT`:

````text
[1155-4] `barId` may not be 2 chars — guard it.
```suggestion
        if (barId != null && barId.length() <= 2) {
            fooInfo.setDisplayId(barId);
        }
```
````

The block must contain the full replacement for the commented line range and nothing else. Use it only for drop-in code changes on changed lines — not for "add a test", multi-file edits, or anything that isn't a direct replacement; those keep their before/after in the markdown.

### File C: `pr_<N>_threads.html` (thread dashboard)

Render `${CLAUDE_SKILL_DIR}/references/threads-template.html` into `pr_<N>_threads.html`: fill `{{N}}`, `{{OWNER}}`, `{{REPO}}`, `{{TITLE}}`, `{{GENERATED}}`, and one `<tr>` per thread root from the fetch in **Thread links** — the Thread cell links to `<PR_URL>#discussion_r<id>`, plus File:Line and a short summary of what each thread asked (wrap code tokens in `<span class="c">…</span>`). Add `class="new"` to threads raised this round. This is the styled, clickable view of every review thread on the PR — yours, Copilot's, and other reviewers'.

Skip File C only when the fetch returned no threads (fresh pre-post review with no existing comments); say so in one line and continue. File C is not covered by the validator.

**Validate artifacts:** Run `bash ${CLAUDE_SKILL_DIR}/scripts/validate-artifacts.sh <N> <REVIEWS_DIR>` as a single Bash call. Run the script itself — do not reimplement its checks inline with `ls`/`jq`, and do not assume its result. Its exit code is authoritative.

- Exit 0 → stdout is `ARTIFACTS_OK comments=<count>` — note the comment count for the Step 10 decision.
- Exit non-zero → STOP with the script's stderr. Fix the artifact issue and re-run before continuing.
- Re-review that migrated a legacy file: only after `ARTIFACTS_OK`, delete the legacy file in a single Bash call with an absolute path — `rm -f <REVIEWS_DIR>/pr-review-<N>.md`. If validation did not pass, leave the legacy file untouched.

---

## Step 10 — Print the command (NEVER run it)

> **Important:** Print the command as assistant/markdown text — do NOT run it via `echo` or `cat` in a Bash tool call (the enforcement hook matches any Bash command containing `create`, which would block it).

First resolve these values (reused in every block below). In every printed command, write `<CLI>` and `<REVIEWS_DIR>` as their full Step 0 values so the user can paste the command as is:
- `REVIEW_MD` = `<REVIEWS_DIR>/pr_<N>_review.md`
- `PR_URL`    = `https://github.com/<owner>/<repo>/pull/<N>`
- `WORKTREE`  = the worktree path from Step 5
- `comments`  = inline-comment count from `ARTIFACTS_OK comments=<count>` (Step 9)
- `markdown_only` = the `### [<N>-<n>] <Severity> — …` findings in `REVIEW_MD`'s `## Review Comments`
  that are NOT in `pr_<N>_comments.json` (cross-file / architectural findings with no diff
  line). Keep each one's ID + file + short title.

**Coverage note (print this first, always).** So the user knows what will and won't appear on GitHub:

> Findings: <total> total — <comments> posted inline on the PR, <markdown_only count> markdown-only (NOT on the PR).
> Not posted to the PR (markdown-only — see the review file):
>   - `[<N>-<n>]` `<file>` — <short title>
>   - …

If `markdown_only` is empty, print instead: `> All findings map to diff lines and will appear inline on the PR.`

If `comments == 0` (architecture-only review): do NOT print a `create` command. Print instead —

```
— Nothing to post inline —
Every finding is markdown-only, so there is no PR draft to create. The review file is the deliverable:

  Review file:  <REVIEW_MD>
  PR:           <PR_URL>

Read the code alongside the review — open the worktree (already on the PR branch) in IntelliJ:
  idea <WORKTREE>
```
Then skip the "Offer to post" step and go to Step 11.

**Fresh review:**

```
— Ready to create pending draft —
Run this command yourself to post the draft:

  python3 <CLI> --host github.com create <owner>/<repo> <N> \
    --comments-file <REVIEWS_DIR>/pr_<N>_comments.json

Then open IntelliJ → PR tool window → Refresh to see your draft comments.
Submit (or edit/delete) from IntelliJ or the GitHub UI.
NEVER pass --body. The draft is private until you submit.

  Review file:  <REVIEW_MD>
  PR:           <PR_URL>
```

**Re-review (may have an existing PENDING draft):**

```
— There may be an existing pending draft —
Check first:
  python3 <CLI> --host github.com list <owner>/<repo> <N>

If a PENDING review exists, delete it:
  python3 <CLI> --host github.com delete <owner>/<repo> <N> <REVIEW_ID>

Then create the new draft:
  python3 <CLI> --host github.com create <owner>/<repo> <N> \
    --comments-file <REVIEWS_DIR>/pr_<N>_comments.json

  Review file:  <REVIEW_MD>
  PR:           <PR_URL>
```

**Offer to post:** After printing, use AskUserQuestion:

> "Ready to create the pending draft?"

- **"Post it now"** → print as assistant text (not a Bash call):
  > To post from this REPL, type the following in the prompt (the `!` prefix bypasses the hook and runs directly in your terminal):
  > `! python3 <CLI> --host github.com create <owner>/<repo> <N> --comments-file <REVIEWS_DIR>/pr_<N>_comments.json`

  When the user runs it via `!` and `Pending review created: id=<REVIEW_ID>` returns, print the **post-creation summary** below. (If the user says they will run it in their own terminal instead, print the same block immediately, omitting the review id.)

  ```
  — Draft created —
  Pending review <REVIEW_ID> — <comments> inline comment(s). Private until you submit.

  PR:           <PR_URL>
  Review file:  <REVIEW_MD>

  Open the worktree (already on the PR branch) in IntelliJ:
    idea <WORKTREE>
  Then: PR tool window → Refresh → select PR #<N> to see and submit your draft.
  ```
- **"Not yet — I'll post later"** → still print the `PR:` and `Review file:` lines so the user has them, then continue.

**Backfill thread links (after you post the draft).** Draft comments already carry their `r` id, so this runs as soon as the draft exists — no wait for submission. Once the user confirms they posted, confirm with AskUserQuestion:

> "Draft posted? I'll grab the thread IDs and fill in the Thread column."

- **"Yes — grab them"** →
  1. Fetch the draft's comments (read-only, single Bash call) using the `REVIEW_ID` from create: `gh api repos/<owner>/<repo>/pulls/<N>/reviews/<REVIEW_ID>/comments --paginate`. Without a `REVIEW_ID` (draft made elsewhere) or if the review is already submitted, use `gh api repos/<owner>/<repo>/pulls/<N>/comments --paginate` instead.
  2. Take thread roots (null `in_reply_to_id`) whose `body` begins with a `[<N>-<n>]` tag; read each one's `id` and `html_url`.
  3. Edit `pr_<N>_review.md`: for each matched finding, replace the `-` in the Finding Index `Thread` column with `[#r<id>](<html_url>)`.
  4. Regenerate `pr_<N>_threads.html` (File C) from the full thread set.
  5. Report in one line — `Backfilled <k> thread links; dashboard updated.` — then print `open <REVIEWS_DIR>/pr_<N>_threads.html`.
  - If no tagged roots come back, the draft comments aren't visible yet: say so and retry once `create` has completed.
- **"Not yet"** → skip; the Thread column stays `-` until you re-trigger this backfill or a later re-review fills it.

---

## Step 11 — Summary and follow-up

Write a brief findings summary: 4-8 bullets grouped by severity (Must resolve → Should address → Strengths). Ground each bullet in the review written in Step 9 — be specific, not generic.

If File C was written, point the user to the thread dashboard: `open <REVIEWS_DIR>/pr_<N>_threads.html`.

Then use AskUserQuestion:

> "Anything else to discuss or follow up on before closing out?"

- **Close out now** → proceed to Step 12.
- **I have a question / follow-up** → address it, then repeat this question until the user is ready to close out.

---

## Step 12 — Cleanup (ask)

The review always runs from a worktree — created this run or reused from a prior review — and either way it is removable once the review is posted. Always run this step.

Use AskUserQuestion to ask:

> "Remove the review worktree at `<WORKTREE>` now? (The review files in the reviews folder are unaffected. Note: if you opened it in IntelliJ from Step 10, removing it closes/breaks that project — keep it until you've submitted the review.)"

If the user answers Yes:
1. Remove the worktree (separate Bash call):
   ```
   git -C <REPO_ROOT> worktree remove <WORKTREE>
   ```
2. Delete the local branch (separate Bash call):
   ```
   git -C <REPO_ROOT> branch -D <BRANCH>
   ```

If `worktree remove` errors (uncommitted changes, or the directory is open in an editor), report the error and leave the worktree in place — do not force-remove, and do not delete the branch. Step 12 is the last step; a failed removal never fails the run.

If the user answers No, leave the worktree in place; the next review of this PR reuses and refreshes it (Step 5).
