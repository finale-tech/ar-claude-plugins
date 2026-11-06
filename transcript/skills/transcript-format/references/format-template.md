# Transcript Format Template

Use this template for cleaned transcript output.

## Full Template

```markdown
# Meeting Transcript

**Date**: [Extract from filename or context, e.g., "November 2024"]
**Participants**: Speaker 1, Speaker 2, Speaker 3
**Topic**: [Brief topic if clear from content]
**Source**: [Original filename]

---

## Transcript

**Speaker 1**: [Opening statement, cleaned of filler words. Break long monologues into paragraphs for readability.]

[Continue with natural paragraph breaks within a single speaker's turn when they change topics or pause.]

*[Screen share - relevant topic or document name]*

**Speaker 2**: [Response to Speaker 1. Preserve their own words while removing fillers.]

**Speaker 1**: [Continuation. Remove fillers only — do not condense or rephrase.]

**Speaker 3**: [New participant joining the conversation.]

*[Looking at diagram - architecture overview]*

**Speaker 2**: [Technical discussion continues. Keep all technical terms exactly as spoken.]

---

## Key Takeaways

### Decisions Made
- [Clear statement of what was decided]
- [Another decision, if any]

### Agreements
- [What was agreed upon]
- [Include who agreed if clear from context]

### Action Items
- [ ] [Specific action with responsible party if mentioned]
- [ ] [Another action item]

### Open Questions
- [Questions raised but not resolved]
- [Topics needing follow-up discussion]
```

## Section Guidelines

### Header Section
- **Date**: Best effort from filename or context
- **Participants**: List speaker labels as-is (Speaker 1, etc.)
- **Topic**: Only if clearly stated or obvious
- **Source**: Original filename for reference

### Transcript Section
- One blank line between different speakers
- Use `**Speaker N**:` format for attribution
- Add `*[Visual context]*` for screen shares, diagrams
- Break long monologues into paragraphs
- Remove filler words only — do not rephrase or condense substantive content
- Preserve the speaker's own sentence structure

### Key Takeaways Section
- **Decisions Made**: Concrete choices that were finalized
- **Agreements**: Consensus points, even informal ones
- **Action Items**: Use checkbox format `- [ ]` for trackability
- **Open Questions**: Unresolved items needing follow-up

## Examples

### Filler Removal
Before: "So, uh, what I'm thinking is, like, you know, we should probably, um, go with Option A."
After: "So what I'm thinking is we should probably go with Option A."

### Confirmation Dedup (same speaker only)
Before: "Right, right, right. Okay. Yeah. So what I'm saying is..."
After: "Right. So what I'm saying is..."

### Stutter/False Start Removal
Before: "So, so it it it is added as part of phase 2 code changes."
After: "So it is added as part of phase 2 code changes."

### Filler-Only Removal (keep sentence structure)
Before: "I guess what I'm wondering is the schema - not the schema, but like some form of schema, kind of like how you say the U in action column might mean something."
After: "I guess what I'm wondering is the schema — not the schema, but some form of schema, how the 'U' in the action column might mean something."

Before: "That makes sense. That makes a lot of sense. Do you have by any chance maybe kind of like a visual of a table that I can just kind of look at to build this, or like a table in the warehouse?"
After: "That makes sense. Do you have a visual of a table that I can look at to build this, or a table in the warehouse?"

### Visual Context
Before: "Let me share my screen... okay can you see this? So this is the architecture."
After: "*[Screen share - architecture diagram]* So this is the architecture."

### Paragraph Breaks
Before: [Single long paragraph spanning multiple topics]
After: [Multiple shorter paragraphs, each focused on one topic]

## Asset Naming Guidelines

When processing transcripts with associated images/screenshots, rename generic files to descriptive names:

| Generic Name | Descriptive Name |
|--------------|------------------|
| `img1.png` | `database-schema-overview.png` |
| `img2.png` | `query-results-example.png` |
| `screenshot.png` | `console-table-view.png` |
| `frame_00001.jpg` | `architecture-diagram-slide.jpg` |

Reference renamed assets in the transcript with markdown links:
```markdown
*[Screen share: [database-schema-overview.png](assets/database-schema-overview.png)]*
```
