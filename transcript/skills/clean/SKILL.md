---
name: clean
description: Polish a raw transcript into clean, readable markdown. Supports .md, .txt, .vtt, and .docx input.
argument-hint: <transcript-path> [-o/--output <path>] [-c/--context <folder>]
allowed-tools: Read Write Edit Glob Grep Bash
---

# Clean Transcript

Clean the raw transcript at `$0` into polished, readable markdown.

Run this skill in default permission mode, not plan mode — it writes the output file directly. If you notice you are in plan mode, say so and ask the user to exit before continuing; do not reason your way around it or let that reasoning leak into the output file.

## Step 1: Parse arguments

- **`$0`** — transcript file path (required). If `$ARGUMENTS` is empty, ask the user for the path and stop until they give one.
- **`-o`** / **`--output`** `<path>` — output file path (optional). If omitted, auto-generate using the naming convention below
- **`-c`** / **`--context`** `<folder>` — path to a folder containing context documents (optional). When given, read all files in that folder (.md, .txt, .pdf, .docx) before cleaning to inform the transcript with background knowledge about topics, people, terminology, and acronyms discussed.

## Output naming convention

When no output path is provided, generate the filename as:

```
[DATE]_[TIME]_[title].md
```

- **DATE**: `YYYYMMDD` format. Extract from the transcript metadata, filename, or content (e.g., "February 13, 2025" → `20250213`)
- **TIME**: `HHMMSS` format (24h). Extract from the transcript metadata or filename if available. If no time is found, omit it (e.g., `20250213_quarterly_planning_review.md`)
- **title**: A short descriptive title auto-generated from the transcript content. Lowercase, words separated by underscores, no special characters. Keep it concise (3-6 words). Examples:
  - `quarterly_planning_review`
  - `api_migration_overview`
  - `checkout_redesign_walkthrough`
  - `weekly_team_sync`

Write the output file in the same directory as the input file.

## Step 2: Load context (only with `--context`)

If no `--context` folder was given, skip this step.

**IMPORTANT: Complete this step fully before proceeding to Step 3. Do NOT read context files and process the transcript in parallel — proper understanding of the transcript depends on having all context loaded first.**

1. List all readable files in the folder (`.md`, `.txt`, `.docx`, `.pdf`)
2. Read each file to understand the domain context — these may include project docs, architecture overviews, glossaries, org charts, or prior meeting notes
3. Confirm you have finished reading all context files before moving on
4. Use this context to:
   - Resolve ambiguous references in the transcript (e.g., "that system" → the specific system name)
   - Correct technical terms and acronyms that the speaker may have mumbled or that speech-to-text garbled
   - Add richer visual context notes when speakers reference diagrams or docs you now recognize
   - Improve the Key Takeaways with accurate project terminology

Do NOT insert context information that wasn't discussed in the meeting. The context helps you understand what was said, not add to it.

## Step 3: Detect format and convert if needed

Check the file extension of the input path:

- **`.md` or `.txt`** — Read directly, no conversion needed
- **`.docx`** — Convert to plain text first. On macOS use `textutil`; elsewhere use `pandoc`:
  ```bash
  textutil -convert txt -output /tmp/transcript_raw.txt "<input-path>"
  ```

  ```bash
  pandoc "<input-path>" -t plain -o /tmp/transcript_raw.txt
  ```

  Then read `/tmp/transcript_raw.txt` as the source. If neither tool is installed, stop and tell the user to install one.
- **`.vtt`** — Read directly. Strip the `WEBVTT` header, segment IDs, and timestamp lines (`HH:MM:SS.mmm --> HH:MM:SS.mmm`). Keep only the speaker tags and spoken text.

## Step 4: Clean the transcript

1. Check for images/screenshots in the same folder as the transcript or an assets subfolder
2. Apply the **transcript-format** skill rules to clean the content
3. Rename any generic image files to descriptive names
4. Generate a Key Takeaways section at the end

The transcript-format skill provides all cleaning rules, condensation patterns, and the output format template. Follow those rules — do not invent additional ones.

To add a System Findings section afterwards, run `/transcript:findings <output-file>`.

Now process: $ARGUMENTS
