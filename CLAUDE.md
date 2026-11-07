# Working on these plugins

This repo is the `arnaud-plugins` local marketplace: `advisor`, `dev-tools`, `diagram-docs`, `transcript`. It is public — never commit personal data, names, account IDs or secrets.

## advisor

### Two places, never mixed

- **The plugin (this repo):** skills, scripts, references, and the starter templates in `advisor/skills/create/templates/`. Templates are blank forms: no patterns, instincts, incident stories or anything else drawn from the user's own work — that content lives only in the data folder. Skills reference plugin files with `${CLAUDE_SKILL_DIR}/...`.
- **The data (`~/.advisor/<name>/`, private):** created once by `scripts/create-domain.sh` from the templates, then owned by the user. It holds everything personal, including who the user is (`## You` in `advisor/status.md`) and the domain's sources (Domain Sources, Repos, Slack Sources in the same file). Skills get its path as `DOMAIN_PATH` from `scripts/preflight.sh`; never hardcode it. A template change only affects domains created afterwards.

### Design rules — keep these when editing

- **Scripts own the mechanics; skills call them and trust the exit code.** Keep deterministic work (domain lookup, scaffolding, extraction, counts, validation, rotation) in scripts, not prose steps.
- **One domain lookup.** Every skill that touches data starts with `preflight.sh`. Don't re-describe the lookup in prose.
- **Fail hard, no silent skips.** A failed script or unreachable source stops the run with a named reason. Never present incomplete output as complete.
- **Coverage gate.** Every source a run must touch is a checkbox in `.cache/coverage.md`; `validate.sh` blocks until all are checked. Add a box when you add a source.
- **Query real state, never infer.** PR/ticket/approval status comes from a live query (`gh`, Jira MCP), not from worklog wording. Never merge two identities.
- **No compound Bash** (`&&`/`||`) — one command per call; use `git -C <path>` for other dirs.
- **Compose via scripts and shared references.** One exception: `next` invokes `sitrep --since <ts>` (which is why `sitrep` is model-invocable). `am` does not gather — it reads what `sitrep` produced. The scan definition lives once in `references/process.md`, run at `full` (sitrep) or `--since` (next) scope.
- **Bounded reads.** Get the last session date from `LAST_SESSION_DATE`; never read the whole `session-log.md` for a date. Rotation keeps that file small.
- **No how-to text in the data folder.** The skills and `/advisor:help` explain themselves; data files hold data.
- **Refer to patterns by name, never by number.** Users delete patterns from `operating-manual.md` once they've mastered them, so a number would point at the wrong pattern; say "if it's still in the manual".
- **Retro never rewrites the user's settings** in `status.md` (`## You`, Domain Sources, Repos, Slack Sources) — only the snapshot above them.

### Gotchas

- **`allowed-tools` must list every MCP tool a skill calls** (e.g. `mcp__plugin_slack_slack__*`). An omitted tool fails silently — the source looks handled but returns nothing.
- **MCP tool names are runtime-specific, and a name that doesn't resolve fails silently too.** The names in `allowed-tools` are the Claude Code ones (`mcp__atlassian__*`, `mcp__plugin_slack_slack__*`). Other runtimes expose the same servers under different names — Cowork uses per-connector identifiers (`mcp__<connector-id>__slack_read_channel`), and has no `gh` binary at all, so GitHub goes through `mcp__github_enterprise__*`. When running a skill somewhere other than Claude Code, map the names to that runtime's before trusting a source as covered; `protocol.md` → "GitHub access" states the GitHub contract independently of the tool.
- **Bundled deps:** the session extractor is `scripts/extract_sessions.py` (used by `gather.sh` and the `worklog` skill); the todo-mining patterns are in `references/process.md`. Scripts find both relative to their own folder.
- **Dates:** never compute in your head; run `date` (or use preflight's `TODAY`/`YESTERDAY`).

### Editing and testing

- After edits, reload so a running session picks them up: restart Claude Code or `/plugin marketplace update arnaud-plugins`.
- Scripts take env overrides — `ADVISOR_HOME` (instead of `~/.advisor`), `ADVISOR_EXTRACT_SCRIPT`, `ADVISOR_TODOS_PROCESS` — and `gather.sh` / `spawn-worker.sh` take the transcripts and tasks folders as arguments, so you can fixture-test them without touching real data: e.g. `ADVISOR_HOME=<tmp> bash advisor/scripts/create-domain.sh test`, then `preflight.sh` against it. Run `bash -n` on every script.
- Verify a change end-to-end with a live `/advisor:sitrep` then `/advisor:am`: look for the progress map, the script tokens (`PREFLIGHT_OK`, `GATHER_OK`, `SITREP_OK`, `BRIEF_OK`, `ROTATE_OK`), a populated `.cache/`, and `archive/`.
- Skills invoke scripts via `bash <script>`, so an execute bit is not required; keep scripts `chmod +x` for consistency.
