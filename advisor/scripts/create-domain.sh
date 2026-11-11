#!/usr/bin/env bash
# create-domain.sh — scaffold a new advisor domain from the starter templates.
#
# Usage: create-domain.sh <name>
#   name  the domain name: lowercase letters, digits and dashes (e.g. career)
#
# Builds ${ADVISOR_HOME:-$HOME/.advisor}/<name>/ by copying skills/create/templates/
# and filling in {{DOMAIN}}, {{PREFIX}} (first 3 letters of the name, uppercased:
# the commitment-ID prefix), {{TODAY}}, {{DOW}} and {{DOMAIN_PATH}} (the new
# folder's own path, so the starter work tracker can be referenced by path). Refuses if the folder already
# exists — it never overwrites data. The copy is built in a temp folder and moved
# into place only when complete, so a failure never leaves a half-built domain.
#
# Stdout on success:
#   DOMAIN_PATH=<absolute path>
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
[ ! -e "$DEST" ] || fail "$DEST already exists — refusing to overwrite it."

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

mv "$TMP" "$DEST"

echo "DOMAIN_PATH=$DEST"
echo "CREATE_OK"
