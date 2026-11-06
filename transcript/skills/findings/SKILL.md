---
name: findings
description: Append a "System Findings" section to one or more cleaned meeting transcripts — system-level technical facts stated in the meeting, attributed to speakers. Use when the user asks to add or run system findings on cleaned transcript files (typically after /transcript:clean); never run it unasked.
argument-hint: <transcript-path> [<transcript-path> ...]
allowed-tools: Read Write Grep Bash Agent
---

# System Findings

Append a `## System Findings` section to each cleaned transcript in `$ARGUMENTS`.

Run this skill in default permission mode, not plan mode — it appends to the transcript files. If you notice you are in plan mode, say so and ask the user to exit before continuing.

## Step 1: Resolve files

- Each argument is a path to a cleaned transcript (`.md`). If `$ARGUMENTS` is empty, ask the user for the path(s) and stop until they give them.
- For each file: if it does not exist, report `ERROR <name> (file not found)` and move on. If it already contains a line `## System Findings`, report `SKIP <name> (already has findings)` and move on.

## Step 2: Generate findings in a fresh context

Findings must come from the transcript alone. Anything else in this session — context documents read by `/transcript:clean --context`, earlier conversation, your own knowledge of the systems discussed — must not leak in. So never generate them in this thread: for each file, launch ONE subagent (`Agent`) with this prompt, filling in the absolute path:

> Read the file `<absolute path>` with the Read tool. It is a meeting transcript. Use nothing but that file's text: no other files, no searches, no outside knowledge. Then reply with ONLY the section below and nothing else.
>
> You are analyzing a meeting transcript to extract system-level technical findings. Produce a "System Findings" section using EXACTLY this format:
>
> ```
> ---
>
> ## System Findings
>
> ### Services & Components
> - Finding text. - *Speaker Name*
>
> ### Data Flows & Integration Points
> - Finding text. - *Speaker Name*
>
> ### Rules, Decisions & Models
> - Finding text. - *Speaker Name*
>
> ### Capabilities & Behavior
> - Finding text. - *Speaker Name*
>
> ### Limitations & Constraints
> - Finding text. - *Speaker Name*
>
> ### Open Questions
> - Finding text. - *Speaker Name*
> ```
>
> RULES:
> - Only include categories that have actual findings. Omit empty categories entirely.
> - Every bullet MUST end with speaker attribution: - *Speaker Name*
> - Prefix uncertain or speculative statements with [tentative]
> - Only extract facts EXPLICITLY stated in the transcript. Do NOT infer, guess, or add information.
> - EXCLUDE: action items, sprint plans, meeting logistics, personal opinions, task assignments.
> - Start your output with the --- separator line. Output ONLY the findings section, nothing else.

Several files can run as parallel subagents.

## Step 3: Validate and append

For each subagent reply:

1. If it does not contain the line `## System Findings`, report `FAILED <name> (malformed output)` and leave the file untouched.
2. Otherwise write the reply, unchanged, to `/tmp/findings_<basename>.md` with the Write tool.
3. Append it to the transcript with two separate Bash calls (the blank lines keep the `---` from turning the previous line into a heading):
   ```bash
   printf '\n\n' >> "<transcript path>"
   ```
   ```bash
   cat "/tmp/findings_<basename>.md" >> "<transcript path>"
   ```
4. Report `ADD <name> ... done`.

Never edit any other part of the transcript.

## Step 4: Summary

Print `Summary: <n> skipped, <n> added, <n> failed`.
