# Advisor Run Guardrails

*These rules bind every sitrep and am run. As the first line of output — before the Step 0 progress map — print a one-line acknowledgment that you are following them (do not paste this whole file).*

---

## The rules

1. **The scripts own the deterministic mechanics; their output is authoritative.** The bundled scripts in `${CLAUDE_SKILL_DIR}/../../scripts/` (`preflight.sh`, `gather.sh`, `validate.sh`) resolve the domain, extract sessions, scan transcripts, count todos, and gate the run. Call them via `bash <path>` and rely on their output: the stdout tokens (`PREFLIGHT_OK`, `GATHER_OK`, `SITREP_OK`, `BRIEF_OK`) and exit codes are authoritative, and each artifact is self-describing (it states its window, counts, and timezone). Because of that you rarely need to re-derive anything — you're free to spot-check, you just don't have to reconstruct what a script already reports.

2. **Read cached data once.** `gather.sh` writes session data to stable files under `${DOMAIN_PATH}/advisor/.cache/`. Read each cache file at most once. Never regenerate a temp file to page through it.

3. **Fail hard. No silent skips.** Any mandatory step failing (a script exits non-zero, a required source is unreachable, an MCP tool errors) stops the run. Name what failed and why. Never continue with partial context and never present incomplete output as complete.

4. **Check off every source.** `gather.sh` writes a coverage checklist (`.cache/coverage.md`). As you complete each remaining source (Slack channels, DMs, active threads, the catch-all sweep, Jira, session log, commitments), mark its box `[x]`. `validate.sh` refuses to pass while any box is unchecked. This is how a skipped Slack mention, a long-running thread that got a new reply, or an unqueried board gets caught before you report.

5. **Query real state; never infer it.** Report a PR's review status, a ticket's status, or an approval only from a live query (`gh`, Jira MCP), never from worklog wording or assumption. Attribute an action to a person only when a source names them — never merge two identities. If you cannot verify, say "unverified," do not guess.

6. **No compound Bash operators.** Never use `&&` or `||` to chain commands. Each command is its own Bash call with absolute paths. For git in another directory use `git -C <path>`.

7. **Ground every claim in a named source.** Each item in a brief, todo update, or accountability point traces to a specific file, transcript line, Slack message, or ticket. If you can't name the source, it doesn't go in the output.

8. **Read the authoritative source; never infer a fact from a proxy that can silently disagree.** Physical file order is not recency — compute the max/min, don't `tail`. A summary field is not the truth — read the underlying data (a PR's stance from `reviews[]` + `submittedAt`, not the sticky `reviewDecision`/`reviewRequests`). A search index is not the source — read the configured Slack channels and their threads directly; use search only to discover sources you don't already know. Reading the source designs the failure out; recovering after a bad proxy result only catches it sometimes.

9. **End each step with a one-line summary.** Close every step with `STEP <name>: <result> · <what changed | anomaly: …>`. The scripts print their own `STEP …` line; add one per skill step. This makes a run greppable straight from its output, so you need not reprint the full progress map each step — advance the markers, print the summary, and move on. If a step hits something unexpected, end its line `· anomaly: <one phrase>` and carry it into the final summary rather than chasing it mid-run.
