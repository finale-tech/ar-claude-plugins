# Domain Resolution

Read this file FIRST, before loading any data files. It resolves `DOMAIN_PATH` — the absolute path to the advisor domain directory.

## Resolution Steps

### 1. Read the config

Read the file `~/.claude/advisor-domains.json`. If it does not exist, STOP and tell the user:

> "Advisor config not found. Create `~/.claude/advisor-domains.json` with your domain paths. Run `/advisor:help` for setup instructions."

### 2. Check for --domain flag

If `$ARGUMENTS` starts with `--domain <name>` (e.g., `--domain personal`):
1. Look up `<name>` in the `domains` object from the config
2. If not found, STOP and tell the user: "Domain '<name>' not found. Available domains: [list all keys from domains object]."
3. If found, set `DOMAIN_PATH` to that domain's `path` value
4. Strip `--domain <name>` from `$ARGUMENTS` (the remaining text is the skill's actual arguments)
5. Skip to step 4 (Validate)

### 3. Check CWD or use default

1. Check if the current working directory contains `./advisor/commitments.md`
2. If yes: set `DOMAIN_PATH` to the current working directory (backward compatibility)
3. If no: read the `default` key from config, look up that domain name in `domains`, set `DOMAIN_PATH` to its `path`

### 4. Validate

Check that `${DOMAIN_PATH}/advisor/commitments.md` exists (use the Read tool). If it does not exist, STOP and tell the user:

> "Domain path '${DOMAIN_PATH}' does not contain advisor data files. Check your config at ~/.claude/advisor-domains.json or run /advisor:create to initialize a new domain."

### 5. Announce

After resolution, announce which domain you're using:

> **Domain:** [domain name] (`${DOMAIN_PATH}`)

## Result

After completing these steps, `DOMAIN_PATH` is set. All subsequent file reads and writes in the skill use `${DOMAIN_PATH}/` instead of `./` for data files. Plugin-relative paths (`${CLAUDE_SKILL_DIR}/...`) are unchanged.
