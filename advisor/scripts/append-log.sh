#!/usr/bin/env bash
# append-log.sh — append ONE entry to session-log.md, strictly at the end.
# The log is append-only and other readers parse it by `## YYYY-MM-DD` headings,
# so the model must never edit the middle of it (a live test showed an `Edit`
# anchored one line short splitting the previous entry). This script opens the
# log in append mode only: it can add text after the last byte, never change
# earlier text.
#
# Usage: append-log.sh <DOMAIN_PATH> <entry-file>
#   <entry-file> must start with a `## YYYY-MM-DD ...` heading.
#
# Stdout on success: APPEND_LOG_OK bytes=<n>
# Exit non-zero with a specific reason on stderr otherwise.
set -euo pipefail

fail() { echo "APPEND_LOG FAILED: $*" >&2; exit 1; }

DOMAIN_PATH="${1:?usage: append-log.sh <DOMAIN_PATH> <entry-file>}"
ENTRY="${2:?usage: append-log.sh <DOMAIN_PATH> <entry-file>}"

command -v python3 >/dev/null 2>&1 || fail "python3 not found on PATH."
LOG="$DOMAIN_PATH/advisor/session-log.md"
[ -f "$LOG" ] || fail "no session log at '$LOG'."
[ -f "$ENTRY" ] || fail "entry file '$ENTRY' not found."

python3 -I - "$LOG" "$ENTRY" <<'PY'
import re, sys

log_path, entry_path = sys.argv[1], sys.argv[2]
with open(entry_path, "r", encoding="utf-8") as f:
    entry = f.read()

if not re.match(r"## \d{4}-\d{2}-\d{2}", entry):
    sys.stderr.write("APPEND_LOG FAILED: the entry must start with a '## YYYY-MM-DD' heading.\n")
    sys.exit(1)
if not entry.endswith("\n"):
    entry += "\n"

with open(log_path, "rb") as f:
    data = f.read()
# One blank line between entries, whatever the log currently ends with.
sep = ""
if data and not data.endswith(b"\n"):
    sep += "\n"
if data and not data.endswith(b"\n\n"):
    sep += "\n"

with open(log_path, "a", encoding="utf-8") as f:
    f.write(sep + entry)
print("APPEND_LOG_OK bytes=%d" % len((sep + entry).encode("utf-8")))
PY
echo "STEP APPEND-LOG: entry appended · ${SECONDS}s · OK"
