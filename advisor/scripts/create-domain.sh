#!/usr/bin/env bash
# create-domain.sh — set up an advisor domain: scaffold a new one from the
# starter templates, or adopt a folder that is already in place.
#
# Usage: create-domain.sh <name>
#   name  the domain name: lowercase letters, digits and dashes (e.g. career)
#
# Target: ${ADVISOR_HOME:-$HOME/.advisor}/<name>/
#
# NEW (the target does not exist): copies skills/create/templates/ and fills in
# {{DOMAIN}}, {{PREFIX}} (first 3 letters of the name, uppercased: the
# commitment-ID prefix), {{TODAY}}, {{DOW}} and {{DOMAIN_PATH}} (the folder's own
# path, so the starter work tracker can be referenced by path). The copy is built
# in a temp folder and moved into place only when complete, so a failure never
# leaves a half-built domain.
#
# ADOPTED (the target exists and holds advisor/commitments.md — a domain copied
# from another machine, or restored): nothing in it is overwritten. Only what the
# templates have and the folder lacks is added: missing files, a missing
# `start_date:` line in the status front matter, and the `work-tracker` path when
# it is still a placeholder and the starter tracker was just added. A path that
# exists but is not a domain is refused.
#
# Stdout on success:
#   DOMAIN_PATH=<absolute path>
#   CREATE_MODE=new | adopted
#   ADDED=<comma-separated list, or none>     (adopted only)
#   CREATE_OK
# Exit non-zero with "CREATE FAILED: <reason>" on stderr otherwise.
#
# Env override (for testing): ADVISOR_HOME
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES="$SCRIPT_DIR/../skills/create/templates"
ADVISOR_HOME="${ADVISOR_HOME:-$HOME/.advisor}"

fail() { echo "CREATE FAILED: $1" >&2; exit 1; }

NAME="${1:-}"
[ -n "$NAME" ] || fail "no domain name given. Usage: create-domain.sh <name>"
[[ "$NAME" =~ ^[a-z0-9][a-z0-9-]*$ ]] || fail "'$NAME' is not a valid name — use lowercase letters, digits and dashes."
command -v python3 >/dev/null 2>&1 || fail "python3 not found on PATH."
[ -d "$TEMPLATES" ] || fail "templates not found at $TEMPLATES."

DEST="$ADVISOR_HOME/$NAME"
MODE="new"
if [ -e "$DEST" ]; then
  [ -f "$DEST/advisor/commitments.md" ] || fail "$DEST already exists and is not an advisor domain (no advisor/commitments.md) — refusing to touch it."
  MODE="adopted"
fi

PREFIX="$(printf '%s' "$NAME" | tr -d '-' | cut -c1-3 | tr '[:lower:]' '[:upper:]')"
TODAY="$(date '+%Y-%m-%d')"
DOW="$(date '+%a')"

mkdir -p "$ADVISOR_HOME"
TMP="$(mktemp -d "$ADVISOR_HOME/.create-$NAME.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

cp -R "$TEMPLATES/." "$TMP/"
find "$TMP" -name '.DS_Store' -type f -delete

# Fill placeholders with python3 (already required by preflight.sh) rather than
# `sed -i`, whose flags differ between macOS and Linux.
python3 - "$TMP" "$NAME" "$PREFIX" "$TODAY" "$DOW" "$DEST" <<'PY'
import os, sys
root, name, prefix, today, dow, dest = sys.argv[1:]
subs = {"{{DOMAIN_PATH}}": dest, "{{DOMAIN}}": name, "{{PREFIX}}": prefix, "{{TODAY}}": today, "{{DOW}}": dow}
for d, _, files in os.walk(root):
    for fn in files:
        p = os.path.join(d, fn)
        with open(p, encoding="utf-8") as f:
            s = f.read()
        for k, v in subs.items():
            s = s.replace(k, v)
        with open(p, "w", encoding="utf-8") as f:
            f.write(s)
PY

LEFT="$(grep -rl '{{' "$TMP" || true)"
[ -z "$LEFT" ] || fail "unfilled placeholders remain in: $LEFT"

if [ "$MODE" = "new" ]; then
  mv "$TMP" "$DEST"
  echo "DOMAIN_PATH=$DEST"
  echo "CREATE_MODE=new"
  echo "CREATE_OK"
  exit 0
fi

# Adopt: add what is missing, change nothing that is there.
ADDED="$(python3 - "$TMP" "$DEST" <<'PY'
import os, re, shutil, sys
tmp, dest = sys.argv[1:]
added = []
tracker_added = False
for d, _, files in os.walk(tmp):
    for fn in files:
        src = os.path.join(d, fn)
        rel = os.path.relpath(src, tmp)
        dst = os.path.join(dest, rel)
        if os.path.exists(dst):
            continue
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copyfile(src, dst)
        added.append(rel)
        if rel == "work-tracker.md":
            tracker_added = True

status = os.path.join(dest, "advisor", "status.md")
if os.path.isfile(status):
    with open(status, encoding="utf-8") as f:
        text = f.read()
    orig = text
    # Front matter: the block between the first two '---' lines after the title.
    fm = re.search(r'^---[ \t]*\n(.*?)^---[ \t]*$', text, re.M | re.S)
    if fm and not re.search(r'^start_date:', fm.group(1), re.M):
        with open(os.path.join(tmp, "advisor", "status.md"), encoding="utf-8") as f:
            tpl = f.read()
        line = re.search(r'^start_date:.*$', tpl, re.M)
        if line:
            block = fm.group(1).rstrip("\n") + "\n" + line.group(0) + "\n"
            text = text[:fm.start(1)] + block + text[fm.end(1):]
            added.append("advisor/status.md: start_date line")
    if tracker_added:
        new_text, n = re.subn(r'^(-\s*work-tracker:\s*)\[[^\n]*$',
                              lambda m: m.group(1) + os.path.join(dest, "work-tracker.md"),
                              text, count=1, flags=re.M)
        if n:
            text = new_text
            added.append("advisor/status.md: work-tracker path")
    if text != orig:
        with open(status, "w", encoding="utf-8") as f:
            f.write(text)
print(", ".join(added) if added else "none")
PY
)"

echo "DOMAIN_PATH=$DEST"
echo "CREATE_MODE=adopted"
echo "ADDED=$ADDED"
echo "CREATE_OK"
