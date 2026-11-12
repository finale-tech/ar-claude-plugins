#!/usr/bin/env bash
# create-domain.sh — scaffold a new advisor domain from the starter templates.
#
# Usage: create-domain.sh <name> [--manual <file>]
#   name             the domain name: lowercase letters, digits and dashes (e.g. career)
#   --manual <file>  an operating manual the user already has. It is copied in as the
#                    domain's operating-manual.md in place of the empty starter. The
#                    file given is read, never moved or changed.
#
# Builds ${ADVISOR_HOME:-$HOME/.advisor}/<name>/ by copying skills/create/templates/
# and filling in {{DOMAIN}}, {{PREFIX}} (first 3 letters of the name, uppercased:
# the commitment-ID prefix), {{TODAY}}, {{DOW}} and {{DOMAIN_PATH}} (the new
# folder's own path, so the starter work tracker can be referenced by path).
#
# Stops if the folder already exists: a domain is created once and never
# overwritten. The copy is built in a temp folder and moved into place only when
# complete, so a failure (a manual that does not pass the check included) never
# leaves a half-built domain.
#
# A manual given with --manual must pass `library.sh check` and hold at least one
# entry under ## Patterns, ## Instincts or ## Daily Rules: those three sections are
# all the advisor reads, so a file without them would install and then be invisible.
#
# Stdout on success:
#   DOMAIN_PATH=<absolute path>
#   MANUAL=starter | MANUAL=imported patterns=<n> instincts=<n> rules=<n>
#   CREATE_OK
# Exit non-zero with "CREATE FAILED: <reason>" on stderr otherwise.
#
# Env override (for testing): ADVISOR_HOME
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES="$SCRIPT_DIR/../skills/create/templates"
ADVISOR_HOME="${ADVISOR_HOME:-$HOME/.advisor}"

fail() { echo "CREATE FAILED: $1" >&2; exit 1; }

USAGE="Usage: create-domain.sh <name> [--manual <file>]"
NAME=""
MANUAL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --manual)
      [ $# -ge 2 ] && [ -n "$2" ] || fail "--manual needs a file path. $USAGE"
      MANUAL="$2"
      shift 2
      ;;
    --*)
      fail "unknown option '$1'. $USAGE"
      ;;
    *)
      [ -z "$NAME" ] || fail "more than one name given ('$NAME' and '$1'). $USAGE"
      NAME="$1"
      shift
      ;;
  esac
done

[ -n "$NAME" ] || fail "no domain name given. $USAGE"
[[ "$NAME" =~ ^[a-z0-9][a-z0-9-]*$ ]] || fail "'$NAME' is not a valid name — use lowercase letters, digits and dashes."
command -v python3 >/dev/null 2>&1 || fail "python3 not found on PATH."
[ -d "$TEMPLATES" ] || fail "templates not found at $TEMPLATES."

DEST="$ADVISOR_HOME/$NAME"
[ ! -e "$DEST" ] || fail "$DEST already exists — nothing was changed. A domain is created once; edit its files directly, or pick another name."

if [ -n "$MANUAL" ]; then
  # A path typed with a leading ~ arrives unexpanded when it was quoted.
  case "$MANUAL" in
    "~/"*) MANUAL="$HOME/${MANUAL#\~/}" ;;
  esac
  [ -f "$MANUAL" ] || fail "no file at $MANUAL — give the path to your operating manual, or leave --manual out to start from the empty one."
  [ -r "$MANUAL" ] || fail "$MANUAL cannot be read."
  [ -s "$MANUAL" ] || fail "$MANUAL is empty."
  python3 -c 'import sys; open(sys.argv[1], encoding="utf-8").read()' "$MANUAL" 2>/dev/null || fail "$MANUAL is not a plain-text (UTF-8) file — the manual is a Markdown file."
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

# The user's manual goes in after the placeholders are filled and checked: it is
# their text, so nothing in it is substituted. `cat` copies the content only, not
# the source file's permissions or extended attributes.
MANUAL_LINE="MANUAL=starter"
if [ -n "$MANUAL" ]; then
  cat "$MANUAL" > "$TMP/operating-manual.md"
  CHECK="$(bash "$SCRIPT_DIR/library.sh" check "$TMP")" || fail "$MANUAL did not pass the manual check (see above) — nothing was created."
  OK_LINE="$(printf '%s\n' "$CHECK" | grep '^LIBRARY_OK' || true)"
  count() { printf '%s\n' "$OK_LINE" | sed -n "s/.* $1=\([0-9][0-9]*\).*/\1/p"; }
  PATTERNS="$(count patterns)"
  INSTINCTS="$(count instincts)"
  RULES="$(count rules)"
  [ -n "$PATTERNS" ] && [ -n "$INSTINCTS" ] && [ -n "$RULES" ] || fail "could not read the entry counts from library.sh check."
  [ $((PATTERNS + INSTINCTS + RULES)) -gt 0 ] || fail "$MANUAL has no entries under ## Patterns, ## Instincts or ## Daily Rules — the advisor would read nothing from it. Nothing was created."
  MANUAL_LINE="MANUAL=imported patterns=$PATTERNS instincts=$INSTINCTS rules=$RULES"
fi

mv "$TMP" "$DEST"

echo "DOMAIN_PATH=$DEST"
echo "$MANUAL_LINE"
echo "CREATE_OK"
