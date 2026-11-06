# Jira Content Templates

*Reference for advisor skills. Used during the artifact sync phase to draft Jira content.*

---

## New Ticket Template (Default)

Use this structure for new Jira stories. Descriptions use Jira wiki markup (h3. for headers).

```
h3. User Story
[Present tense. Frame around "why did we need to spend time on this" — the tactical or strategic gap that justified the work. Not a generic user story; a specific explanation of what breaks if this work doesn't happen.]

h3. Acceptance Criteria
[Outcome-oriented checklist. For retrospective tickets, word the AC so the delivered result closes the loop. For forward-looking tickets, word as targets.]

---
Deliverables are documented in ticket comments using the contextual handoff format.
```

**Per-ticket overrides:** When user story / AC doesn't fit (e.g., a filed bug), use the appropriate format instead (repro steps, expected vs actual behavior).

## Comment Template (Contextual Handoff Format)

Use this for Jira comments that document work done. The goal: another engineer reading this comment can pick up where you left off without asking 15 questions.

```
h3. Context
[What we were trying to do and why — the problem being solved.]

h3. Approach
[What was tried, what tools/methods were used, why this approach was chosen over alternatives. Include what was considered and rejected.]

h3. Findings
[What we learned — results, data, decisions made. Include links to evidence: bug tickets filed, Confluence pages created, PRs submitted.]

h3. Open Items
[What's still unresolved, untested, or blocked. What the next person picking this up should know. Landmines, edge cases, known unknowns.]
```

## Naming Rules

- **Never put "review" in a Jira title.** Frame tickets for the deliverable or feature, not the activity.<!-- RECOVERY-GAP: IMG_8128 line is cut off at the right edge of the photo after "not the a"; "ctivity." is a guess from the next bullet ("outcome-oriented, not activity-oriented"); any further text on this line is missing -->
- **Titles are outcome-oriented**, not activity-oriented.
  - Bad: "Review PR #2503"
  - Good: "Checkout Service Quality — Tech Debt Identification"

## Sprint Scoping Rules

- **Split work that spans sprints** into per-sprint tickets.
- **Current sprint references previous sprint:** "Building on PROJ-XXXX, this story focuses on..."
- **Previous sprint work** → sub-tasks of umbrella story (closed).
- **Current sprint work** → standalone stories (open).

## Cross-Referencing Rules

- **Link related tickets** in descriptions and comments.
- **Include evidence links:** Confluence pages, bug tickets, PRs.
- **Use full URLs** for clickability — Jira auto-linking is not reliable.
  - Example: `[PROJ-6627|https://your-instance.atlassian.net/browse/PROJ-6627]`

## Approval Gate

**Nothing gets written to Jira without explicit user approval.** The skill drafts content and presents it. The user greenlights each action individually.
