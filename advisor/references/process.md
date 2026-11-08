# Action Item Search Patterns — Reference

*This file contains the detailed search patterns and classification rules used by `/advisor:sitrep`'s Todo scan step.*

---

## Transcript Search Patterns

| What | Grep Pattern | Source |
|------|--------------|--------|
| Checkbox action items | `\[[ x]\] \*\*{Name}` | Transcripts |
| Verbal commitments (assigned) | `{Name}.*(to (take\|pick\|create\|review\|check\|investigate\|complete\|file\|document\|send\|set up\|learn\|propose\|deep dive\|sync\|own\|update\|finish\|prepare))` | Transcripts |
| Self-commitments | `{Name}.*(should\|will\|can take\|can pick\|I'll\|I can)` | Transcripts |
| Ownership assignments | `{Name}.*(own\|point of contact\|POC)` | Transcripts |
| PR requests | `{Name}.*review.*PR\|PR.*{Name}` | Transcripts + Slack |

## Scope (window)

The scan runs at one of two windows, chosen by the caller:

- **full** (default) — 7-day lookback. Used by the morning `sitrep`.
- **delta** — since a given timestamp (`--since <ISO>`). Used by `next` each cycle. Restrict every search to messages at or after that timestamp.

## Slack — read the source; search only to discover

Facts about the CONFIGURED channels/DMs (the known list in `status.md` → Slack Sources) come from **reading the source directly**, not from search: the search index is eventually-consistent and can return a transient empty, so it is never the completeness mechanism for a known source. Completeness has two parts — a windowed channel read and a re-read of long-running threads — because neither alone covers everything.

### 1. Windowed channel/DM read — new top-level messages and their threads

For each configured **channel**: `slack_read_channel` over the window (`oldest`/`latest` unix ts). It returns only messages whose own `ts` is in-window — top-level messages posted in the window, each with its reply count and latest-reply time. These channels are thread-dominated (most asks are thread *replies*), so for every returned thread whose latest reply falls in the window, `slack_read_thread` and scan the replies for `<@{SLACK_USER_ID}>` mentions and the person's own posts. For each configured **DM**: the same over the DM's `channel_id`.

A windowed `slack_read_channel` does **not** return a thread whose PARENT predates the window, even when that thread has fresh in-window replies — the parent's `ts` is outside `[oldest, latest]`, so the whole thread is absent from the payload. A long-running escalation thread (parent from weeks ago, still getting nudged) is invisible to this read. Part 2 covers it.

### 2. Active-thread re-read — long-running threads by `thread_ts`

Re-read every thread anchored to an OPEN work-tracker item directly, whatever its parent's date — the Slack analogue of `gh pr view` on active PRs and `getJiraIssue` on active tickets. `gather.sh` extracts the `(channel_id, thread_ts)` pairs from the Slack permalinks on open tracker rows into `.cache/active-threads.txt`; for each pair, `slack_read_thread` and scan replies with a `ts` in the window for `<@{SLACK_USER_ID}>` mentions, others' asks, and the person's own posts. This is what catches an old-parent thread that got a new reply this window. (`next` applies the same at delta scope: each cycle re-read the threads tied to its Active and 🔴 items by `thread_ts` — from their Source links or `.cache/active-threads.txt`.)

Permalink → anchor: `.../archives/<CID>/p<digits>?thread_ts=<TS>&cid=<CID>` gives `channel_id=<CID>`, `thread_ts=<TS>`. A bare `.../archives/<CID>/p<digits>` (no query) is a top-level message whose `thread_ts` is `<digits>` with a dot inserted before the last six figures.

### Search — discovery only

**Search finds sources NOT already covered above** — channels/DMs not in the configured list, and threads not yet anchored to a tracker item. Use `slack_search_public_and_private` with `<@{SLACK_USER_ID}>` and `from:@{SLACK_USERNAME}`, windowed by `after:/before:` (pad a day either side, because Slack's dates are UTC and yours may not be; never `on:`). Flag any channel/DM in the results that isn't configured, to add it; anchor any newly-found active thread to its tracker item so part 2 picks it up next run.

Forms: `from:@username` / `to:@username` for DM search (the `from:<@ID>` form returns zero here); `<@{SLACK_USER_ID}>` is the mention token. If any read or search errors, STOP — never present a source as covered when it wasn't reached.

## DM Context Enrichment

When a DM message is classified as actionable, read surrounding context before creating the todo entry:

- **If the message has a `thread_ts`:** use `slack_read_thread` with the message's `channel_id` and `thread_ts` to pull the full thread.
- **If the message is unthreaded (top-level DM):** use `slack_read_channel` with the DM's `channel_id`, requesting up to 10 messages around the actionable hit (use `oldest` and `latest` timestamps to window the read).

This context is used to write a more informative todo title and to populate the detail file if the item is a full task. The classifier should re-evaluate after seeing context — a message that looked actionable in isolation may turn out to be resolved in a follow-up message.

## GitHub Search Patterns

| What | Command |
|------|---------|
| PRs requesting review | `gh pr list --repo {REPO} --state open --search "review-requested:{USERNAME}" --json number,title,url,author,createdAt` |

Repos: the `## Repos` section of the domain's `advisor/status.md` (one `owner/repo` per line).
Username: `GITHUB_USERNAME` from preflight.

For PRs already on the plate (active or 🔴 items), check live state changes since the window. Run exactly:

`gh pr view <N> --repo {REPO} --json state,reviews,comments,statusCheckRollup --jq '{state, reviews: [.reviews[] | {author: .author.login, state, submittedAt}]}'`

Decide the current stance from the **most recent `reviews[]` entry by `submittedAt`**: a submitted review shows `state` = APPROVED / CHANGES_REQUESTED / COMMENTED; a `PENDING` entry is an unsubmitted draft. **Never** decide from `reviewDecision` or `reviewRequests` — both are *sticky*: they keep showing a stale `CHANGES_REQUESTED` (or a cleared review-request) after a newer review was submitted. This is the exact bug that produced a false "not submitted" read. Valid `--json` fields include `state`, `reviews`, `comments`, `statusCheckRollup` — `checks` is NOT a valid field and errors.

## Jira Search Patterns

Use the Atlassian MCP (`searchJiraIssuesUsingJql`, `getJiraIssue`), scoped by the window.

| What | JQL / call | Notes |
|------|------------|-------|
| Assigned, recently updated | `assignee = currentUser() AND updated >= "<since>" ORDER BY updated DESC` | New comments or status changes since the window |
| Active-item tickets | `getJiraIssue <KEY>` for each ticket referenced by an active or 🔴 item | Confirm current status + last comment |

For a full-scope run, use `updated >= -7d` and also query recently-closed (`status in (Closed, Done) AND updated >= -7d`).

## What to Look For in Slack

**Mentions:**
- Direct requests ("can you do X")
- FYI tags on decisions that affect their work
- PR review requests
- Follow-ups on earlier commitments ("did you get a chance to...")

**Messages from person:**
- "I'll do X"
- "I can take that"
- "Just fyi I filed this bug: ..."
- "Sounds good, I will catchup today"

## Classification

### Status
- **Open** — no evidence of completion
- **In progress** — partially done or acknowledged
- **Resolved** — completed, confirmed in Slack or code
- **Superseded** — made irrelevant by a design change or decision

### Confidence

Tag each surfaced fact by how it was established, with a time:

- **verified-live** — confirmed by a live query this run (`gh pr view`, `getJiraIssue`, a Slack read). Include the time, e.g. `verified-live 14:31`.
- **inferred** — deduced from an indirect signal (e.g. a worklog mention) but not directly confirmed.
- **unverified** — carried from a prior run, not re-checked this window; note when it was last confirmed (`unverified since 11:00`).

Do not report a status as fact unless it is verified-live this run. Downstream escalation (`next` notifications, `am` accountability) acts only on verified-live items.

### Weight
- **Quick task** — single-action items: FYI tags, "check this", "take a look", "review this PR", "can you please [verb]", CC mentions with implicit expectation. No multi-step scope.
- **Full task** — explicit ownership, multi-step deliverables, design work, investigation with scope, ongoing responsibilities.

Detection heuristic for quick tasks:
- The message is tagging the person with `fyi`, `cc:`, or a single ask
- The request is a single verb + object ("check this", "review PR #X", "take a look at this thread")
- No explicit deadline, scope description, or multi-step instructions
- No ownership language ("own", "lead", "be the POC for")

### Format

All items use one-line format:
```
- [ ] **Title** | YYYY-MM-DDTHH:MMZ | [Source](url)
```

If context won't fit in the title, create a detail file at:
- PR items → `tasks/pr_reviews/pr_<NUMBER>_review.md`
- Non-PR items → `tasks/<slug>.md`

### Ordering
All open items in a single flat list, sorted by date ascending. Use due date if known, otherwise source date.

### Editing safety
When updating the tracker, change only the target row(s). Never delete or overwrite a row you have no new information for — a row without an update stays exactly as it is. Prefer a targeted single-row edit over rewriting a whole table block, and re-read the section after a large edit to confirm no unrelated row was dropped.

### Context to Capture
- What the item is
- Who assigned it
- Date (due date or source date)
- Source link (Slack permalink or meeting filename)
- For full tasks only: why it was assigned, any links (PRs, Jira tickets, Confluence pages)

## Resolution Cross-Reference

Check whether open items have been resolved by:

1. Searching Slack for follow-ups — did someone confirm it's done?
2. Checking if the design changed — later meetings may have removed the need
3. Looking for "filed" or "done" messages from the person in Slack
4. Checking Jira ticket references — if a ticket was mentioned, was it filed?

## Notes

- Meeting transcripts have a consistent format: metadata header, transcript body, key takeaways with `### Action Items` section, then `## System Findings`. Action items are in the takeaways section.
- Slack context is important — a mention doesn't always mean a task. FYI tags, CC tags, and informational mentions should be noted but not treated as action items.
- Design decisions in later meetings can supersede tasks from earlier meetings. Always check chronologically.
