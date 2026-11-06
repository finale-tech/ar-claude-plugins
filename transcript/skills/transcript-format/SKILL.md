---
name: transcript-format
description: Use when cleaning, polishing, or formatting meeting transcripts, transcriptions, or raw speech-to-text output. Provides rules for transforming raw transcripts into clean, readable markdown.
user-invocable: false
---

# Transcript Format Skill

This skill provides rules and guidelines for cleaning raw meeting transcripts into polished, readable markdown.

## When This Skill Applies

This skill activates when:
- Cleaning or polishing a transcript
- Formatting raw speech-to-text output
- Processing meeting notes or recordings
- Working with WhisperX or similar transcription output

## Core Principles

### 1. Faithful Cleanup
Preserve the speaker's own words and sentence structure. Remove only filler words, stuttering, false starts, and mispronunciations. Fix obvious grammar errors. Collapse repetitive confirmations by the same speaker. **Never rewrite, rephrase, or restructure a speaker's sentences.** The output should read like what the person meant to say — using their words, not yours.

### 2. Minimal Intervention
Remove filler words and fix grammar. Do NOT condense, summarize, or rephrase. If a speaker is wordy, they stay wordy.
Your job is to remove noise (fillers, stutters), not to edit for conciseness.

### 3. Add Visual Context
Note when speakers reference screen shares, documents, diagrams, or other visuals using italicized brackets: `*[Screen share - architecture diagram]*`

### 4. Rename Assets
Rename generic image files (img1.png, screenshot.png) to descriptive names that reflect their content (e.g., `database-schema-overview.png`).

### 5. NO Timestamps
Do not include timestamps in the output. They are error-prone and not essential for the document's value.

### 6. NO Speaker Renaming
Keep original speaker labels (Speaker 1, Speaker 2, etc.). The user will rename these manually after review.

### Hard Rules (Never Violate)

1. **Never rewrite a sentence.** Remove fillers from the speaker's sentence, but keep their phrasing and structure.
2. **Never merge multiple speaker turns into one.** If Speaker A says something, Speaker B says "Yeah", and Speaker A continues — keep all three turns.
3. **Never drop short turns.** Turns like "Yeah," "Okay," "Got it" stay in the transcript. Only collapse when repeated in sequence by the same speaker (e.g., "Yeah, yeah, yeah" → "Yeah").
4. **Never summarize a discussion.** If two people go back and forth for 20 lines about a topic, all 20 lines stay (minus fillers).
5. **Preserve inline references.** URLs, file paths, ticket numbers, service names stay exactly where mentioned.

### Anti-Pattern Examples

| Raw | WRONG (old behavior) | CORRECT (new behavior) |
|-----|----------------------|------------------------|
| "Yeah, well, one thing I was going to say is, you know, I was on PTO, you know, for most of the day yesterday, right? So I cannot, and I'm looking at the threads here to catch up, but, you know, a couple of the meetings were not recorded. So I may be behind a little bit." | "I was on PTO most of yesterday and a couple of meetings weren't recorded, so I may be behind." | "One thing I was going to say is I was on PTO for most of the day yesterday. So I'm looking at the threads here to catch up, but a couple of the meetings were not recorded. So I may be behind a little bit." |
| "So, so it it it is added as part of phase 2 code changes. And my suspicion is bug is in other end, but we can't figure it out where it is. Why is this duplicate call getting published?" | "The publishing was added as part of Phase 2 code changes. My suspicion is the bug is on the other end, but we can't figure out where the duplicate call is coming from." | "So it is added as part of Phase 2 code changes. And my suspicion is the bug is on the other end, but we can't figure out where it is. Why is this duplicate call getting published?" |
| "That makes sense. That makes a lot of sense. Do you have by any chance maybe kind of like a visual of a table that I can just kind of look at to build this?" | "That makes sense. Do you have a sample table I could reference?" | "That makes sense. Do you have a visual of a table that I can look at to build this?" |

The difference: WRONG rewrites the sentence into something the editor thinks sounds better. CORRECT removes only the stutters and fillers while keeping the speaker's actual sentence flow.

## Cleaning Rules

### Remove These Filler Words
- uh, um, ah
- like (when used as filler, not comparison)
- you know, I mean
- sort of, kind of
- basically, actually, literally (when used as filler)
- right? (when used as filler/confirmation)

### Condense These Patterns (ONLY these two)
- Repetitive confirmations by the **same speaker** ("Right, right, right. Okay. Yeah.") → Single acknowledgment ("Right.")
- Stuttering and false starts ("So, so it it it is" → "So it is")

Do NOT condense anything else. Wordy sentences stay wordy — just remove filler words from them.

### Fix These Issues
- Run-on sentences → Break into shorter sentences
- Subject-verb disagreement → Correct
- Unclear pronoun references → Clarify if meaning is obvious
- Incomplete sentences → Complete if meaning is clear

### Preserve
- Technical terminology exactly as spoken
- Speaker's communication style (formal vs casual)
- Key details and nuances
- Questions and responses in order
- Examples, analogies, and illustrations speakers use to explain concepts
- Concrete details (names, numbers, scenarios) used to support a point
- Inline references (URLs, file paths, ticket numbers, service names) exactly where mentioned

## Cleanup Examples

| Before | After |
|--------|-------|
| "Right, right, right. Okay. Yeah. So..." | "Right. So..." |
| "So, so it it it is added as part of" | "So it is added as part of" |
| "I guess what I'm, uh, wondering is the schema — not the schema, but like some form of schema." | "I guess what I'm wondering is the schema — not the schema, but some form of schema." |
| "So basically what I'm saying is, kind of like, you know, we need to consider..." | "So what I'm saying is we need to consider..." |
| "That makes sense. That makes a lot of sense. Do you have by any chance maybe kind of like a visual of a table that I can just kind of look at to build this?" | "That makes sense. Do you have a visual of a table that I can look at to build this?" |
| "For example, if a customer orders on Monday and then changes the address on Tuesday, we'd recalculate shipping at that point — not when the original order was placed." | **Keep as-is** — this is substantive content, not filler. |

## Asset Naming

Rename generic filenames to descriptive ones:

| Before | After |
|--------|-------|
| `img1.png` | `architecture-overview-diagram.png` |
| `img2.png` | `database-query-results.png` |
| `screenshot.png` | `admin-console-schema.png` |

## Output Structure

See [references/format-template.md](references/format-template.md) for the complete output format.

## Writing the Output File

Write the file in chunks so output keeps flowing — some network setups (proxies, gateways) drop a connection after a few minutes with no output, and a long silent think before the first write can trip that.

- Write the header block first (title, date, participants, topic, source) with the Write tool, immediately, before cleaning any content. This starts the stream before the deep pass.
- Then append the cleaned transcript with the Edit tool in 200-300 line chunks, straight through without pausing.
- Never write more than 300 lines in one call.

## Quality Checklist

Before finishing, verify:
- [ ] Speaker's own words preserved — only fillers, stutters, false starts, and grammar errors changed
- [ ] Sentence structure untouched — no rephrasing or restructuring
- [ ] Repetitive same-speaker confirmations collapsed (nothing else condensed)
- [ ] No section headers added within the transcript body
- [ ] Inline references (URLs, paths, ticket numbers) preserved where mentioned
- [ ] Speaker labels unchanged from original
- [ ] No timestamps added
- [ ] Visual context notes included where appropriate
- [ ] Image assets renamed to descriptive names
- [ ] Key Takeaways section captures decisions and actions
