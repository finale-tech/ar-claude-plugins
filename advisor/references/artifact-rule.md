# The Artifact Rule

*Reference for advisor skills.*

---

## The Rule

**Every block of work that took real effort must produce a persistent, linkable, shareable object that exists after you leave the room.**

An artifact is evidence that the work happened — in a form a manager can forward upward.

## The Filter

Apply to every work item during the gather phase:

1. **Did this take more than 30 minutes of real effort?** If no, skip.
2. **Does a persistent, linkable, shareable object exist?** If yes, classify as **Covered**.
3. **Does an artifact exist but it's stale or incomplete?** If yes, classify as **Needs update**.
4. **No artifact exists?** Classify as **Gap** and propose the right artifact type.

## What Counts as an Artifact

| Artifact | Where it lives |
|----------|---------------|
| A Jira ticket (with description, not just a title) | Jira board |
| A Confluence page (design doc, ADR, runbook, LLD) | Confluence |
| A merged or submitted PR | GitHub |
| A filed bug with repro steps | Jira |
| A daily status email | Email |

## What is NOT an Artifact

- A conversation or meeting contribution
- Knowing the answer
- Helping someone debug
- Running tests and finding bugs (until the bugs are filed)
- Analysis that stays in local files
- A branch that was never submitted as a PR
- A Slack message

## Artifact Type Proposals

When a gap is detected, propose the right artifact type:

| Work type | Proposed artifact |
|-----------|-------------------|
| Architecture analysis, design decisions | Confluence page or ADR entry |
| Work stream progress | Jira ticket + contextual handoff comment |
| Bug found in testing | Filed Jira bug with repro steps |
| Code work with no PR | PR submission |
| Tech debt identified from code reviews | Jira ticket |

## The Daily Check

> "If I got hit by a bus right now, could someone find what I just did?"

If no — produce the artifact. **Fifteen minutes max.** It's a packaging exercise, not a new project.
