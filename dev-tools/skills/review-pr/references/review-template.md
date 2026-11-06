# PR #<N> Review: <TICKET> | <title> -- <state>

**PR:** https://github.com/<owner>/<repo>/pull/<N>
**Author:** <author login>
**Base branch:** <headRefName> (merging to <baseRefName>)
**Jira:** <TICKET> (epic: <EPIC_KEY or none>)
**Files changed:** <N> files
**Last updated:** <YYYY-MM-DD>
**Last author commit:** <sha> (<YYYY-MM-DD>) -- "<subject>"

<!--
Template rules (do not copy this comment into the review):
- Keep the sections below in this order. "## Finding Index" is always the first ## section.
- Every finding has a stable ID [<N>-<n>]. It appears in four places: the Finding Index row,
  the finding's ### header, its Recommended Action bullet, and the start of its JSON comment body.
- Status is one of: Open / Resolved / Partially addressed / No longer relevant.
- Thread is [#r<id>](<PR_URL>#discussion_r<id>) once posted, "-" before.
- Write "None" in a section that has nothing to say. Never leave a section empty.
-->

## Finding Index

| ID | File:line | Severity | Status | Thread | Title |
|----|-----------|----------|--------|--------|-------|
| [<N>-1] | `<path>:<line>` | Must resolve | Open | - | <brief title> |

## Context

**Jira <TICKET>:** <summary>

Acceptance criteria:
- <criterion>

**Confluence:**
- [<page title>](<url>): <what it says that matters for this PR>

**Local KB notes:**
- `<file>`: <what it says that matters for this PR>

**Sibling tickets (epic <EPIC_KEY>):** <one or two lines, or None>

## Review History

| Date | Commit | Summary |
|------|--------|---------|
| <YYYY-MM-DD> | `<sha>` | Round 1: <n> findings (<n> Must resolve, <n> Should address, <n> Nice to have). |

## Review Comments

## File: `<path>`

### [<N>-1] Must resolve — <brief title>

Line <line> / `ClassName#methodName`

<What is wrong, why it matters, and what was read to establish it (implementation, not call site).
Name the precedent: how the same thing is done elsewhere in the codebase, with file:line.>

**Before:**
```<lang>
<current code>
```

**After:**
```<lang>
<suggested code>
```

## Verification Coverage

<n> pre-scan obligations — <n> confirmed, <n> cleared with evidence, <n> unverified

**Verification gaps:**
- <obligation> — blocked on <what would settle it>

<!-- Write "**Verification gaps:** None" when there are none. -->

## Resolved Issues

None

<!-- Re-review: - [<N>-<n>] <title> — resolved in `<sha>` (<how>) -->

## CI Status (as of <YYYY-MM-DD>)

| Check | State |
|-------|-------|
| <check name> | SUCCESS |

## Strengths

- <concrete observation about what the PR does well>

## Recommended Action

### Must resolve before merge
- [<N>-1] <action>

### Should address
- None

### Nice to have
- None

### CI
- <All checks green / pending checks to watch>

### Overall Assessment
<One short paragraph: ready to merge after the Must resolve items, needs another round, etc.>
