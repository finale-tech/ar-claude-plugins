# Working on these plugins

This repo is the `arnaud-plugins` local marketplace: `advisor`, `dev-tools`, `diagram-docs`, `transcript`. It is public — never commit personal data, names, account IDs or secrets.

## advisor

### Three parts, never mixed

- **The engine (this repo):** skills, scripts, references, and the starter templates in `advisor/skills/create/templates/`. Templates are blank forms: no patterns, instincts, incident stories or anything else drawn from the user's own work. Skills reference plugin files with `${CLAUDE_SKILL_DIR}/...`.
- **The library (`advisor/library/`, this repo, public):** the general plan, `playbook.md` — the Senior-vs-Staff table, the week-by-week plan, reflection and recalibration, true for any engineer. It is read live through `scripts/library.sh` and never copied into a data folder or a template. Nothing in it may identify the user, an employer, a product, a colleague or a calendar date. The patterns, instincts and daily rules are **not** in the library: they live only in the user's `operating-manual.md`, in full.
- **The data (`~/.advisor/<name>/`, private):** created once by `scripts/create-domain.sh` from the templates, then owned by the user. The script stops if the folder already exists. The one file it takes from the user is an operating manual they already have (`--manual <file>`), copied in place of the empty starter after it passes `library.sh check` and shows at least one entry. It holds everything personal: who the user is (`## You` in `advisor/status.md`), the domain's sources (Domain Sources, Repos, Slack Sources in the same file), and the whole operating manual. Skills get its path as `DOMAIN_PATH` from `scripts/preflight.sh`; never hardcode it. A template change only affects domains created afterwards.

`operating-manual.md` is entirely the user's: every pattern, instinct and rule in it carries its full text, and a pattern's `*Status:*` (`active`, `later`, `mastered`) says whether `am` and `next` check it. `library.sh check` runs inside `preflight.sh` and stops every skill on a heading under Patterns, Instincts or Daily Rules that has no text of its own. (The script can also join a heading to a library entry of the same name — an overlay — should general entries ever be added to the library again; today there are none.)

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
- **Only the user's manual names a pattern, instinct or rule.** Skills, scripts, references and templates never do: the user's list grows, and patterns leave it as they are mastered. Point at the source ("one of the user's active patterns") and let `library.sh mine` supply the name. The same goes for the playbook: refer to "a dimension in the library playbook's table", never a list of them.
- **Library headings are an interface.** Skills refer to playbook sections by name (the Senior-vs-Staff table, the week sections, the recalibration table), so rename one only with a reason, and run `library.sh lint` after any library edit.
- **Skills read the library and the manual through `library.sh`, in the smallest form that does the job.** `index` for the catalogue of playbook sections, `show` for the few that fit, `mine patterns --active` for a run that repeats (`next`). Never read a whole library file in a skill that runs many times a day.
- **Never commit un-generalised text to this repo, not even as a draft.** A push sends every unpushed commit, so text fixed in a later commit is still published in the earlier one. Generalise first, commit second.
- **Examples use obviously fake values** (`PROJ-123`, `PR #42`, `~/code/example-service`), never IDs, names or paths copied from a real run.
- **Retro never rewrites the user's settings** in `status.md` (`## You`, Domain Sources, Repos, Slack Sources) — only the snapshot above them.

### Gotchas

- **`allowed-tools` must list every MCP tool a skill calls** (e.g. `mcp__plugin_slack_slack__*`). An omitted tool fails silently — the source looks handled but returns nothing.
- **MCP tool names are runtime-specific, and a name that doesn't resolve fails silently too.** The names in `allowed-tools` are the Claude Code ones (`mcp__atlassian__*`, `mcp__plugin_slack_slack__*`). Other runtimes expose the same servers under different names — Cowork uses per-connector identifiers (`mcp__<connector-id>__slack_read_channel`), and has no `gh` binary at all, so GitHub goes through `mcp__github_enterprise__*`. When running a skill somewhere other than Claude Code, map the names to that runtime's before trusting a source as covered; `protocol.md` → "GitHub access" states the GitHub contract independently of the tool.
- **Bundled deps:** the session extractor is `scripts/extract_sessions.py` (used by `gather.sh`); the todo-mining patterns are in `references/process.md`. Scripts find both relative to their own folder.
- **Dates:** never compute in your head; run `date` (or use preflight's `TODAY`/`YESTERDAY`).

### Editing and testing

- After edits, reload so a running session picks them up: restart Claude Code or `/plugin marketplace update arnaud-plugins`.
- Scripts take env overrides — `ADVISOR_HOME` (instead of `~/.advisor`), `ADVISOR_EXTRACT_SCRIPT`, `ADVISOR_TODOS_PROCESS`, `ADVISOR_LIBRARY` (instead of `advisor/library`) — and `gather.sh` / `spawn-worker.sh` take the transcripts and tasks folders as arguments, so you can fixture-test them without touching real data: e.g. `ADVISOR_HOME=<tmp> bash advisor/scripts/create-domain.sh test` (add `--manual <fixture.md>` to test the import), then `preflight.sh` against it. Run `bash -n` on every script.
- Verify a change end-to-end with a live `/advisor:sitrep` then `/advisor:am`: look for the progress map, the script tokens (`PREFLIGHT_OK`, `GATHER_OK`, `SITREP_OK`, `BRIEF_OK`, `ROTATE_OK`), a populated `.cache/`, and `archive/`.
- Skills invoke scripts via `bash <script>`, so an execute bit is not required; keep scripts `chmod +x` for consistency.
