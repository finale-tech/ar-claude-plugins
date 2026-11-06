#!/usr/bin/env bash
# rotate-log.sh — keep session-log.md bounded so every reader stays cheap.
# Sorts entries chronologically by their `## YYYY-MM-DD` date, keeps the
# preamble plus the most-recent KEEP entries in the live log (newest last), and
# moves the older ones into <DOMAIN_PATH>/advisor/archive/session-log-<year>.md
# (grouped by the entry's year; undated entries go to session-log-misc.md).
# Sorting by date (not physical position) self-heals an out-of-order log and
# stops a stray old entry from stranding recent ones in the archive. Safe to
# call after every append — stable once the log is sorted.
#
# Usage: rotate-log.sh <DOMAIN_PATH> [KEEP_ENTRIES]   (default KEEP=60)
# Stdout (last line): ROTATE_OK kept=<n> archived=<m>
set -euo pipefail

DOMAIN_PATH="${1:?usage: rotate-log.sh <DOMAIN_PATH> [keep]}"
KEEP="${2:-60}"
case "$KEEP" in ''|*[!0-9]*) echo "rotate-log.sh: KEEP must be a positive integer" >&2; exit 2 ;; esac
[ "$KEEP" -ge 1 ] || { echo "rotate-log.sh: KEEP must be >= 1" >&2; exit 2; }

LOG="$DOMAIN_PATH/advisor/session-log.md"
ARCHIVE_DIR="$DOMAIN_PATH/advisor/archive"

if [ ! -f "$LOG" ]; then
  echo "ROTATE_OK kept=0 archived=0 (no log)"
  exit 0
fi

mkdir -p "$ARCHIVE_DIR"

python3 - "$LOG" "$ARCHIVE_DIR" "$KEEP" <<'PY'
import re, sys, os
from collections import OrderedDict

log_path, archive_dir, keep = sys.argv[1], sys.argv[2], int(sys.argv[3])
with open(log_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

# An entry starts at a top-level H2 heading ("## " at start of line). Anything
# before the first such heading is preamble and is always kept.
entry_start = re.compile(r'^## ')
idxs = [i for i, ln in enumerate(lines) if entry_start.match(ln)]
if not idxs:
    print("ROTATE_OK kept=0 archived=0 (no entries)"); sys.exit(0)

preamble = "".join(lines[:idxs[0]])
entries = ["".join(lines[s:(idxs[j+1] if j+1 < len(idxs) else len(lines))])
           for j, s in enumerate(idxs)]

# Sort chronologically by the entry's date; undated entries sort oldest.
# Stable on original order for entries sharing a date (or undated).
date_re = re.compile(r'^##\s+(\d{4}-\d{2}-\d{2})')
def date_key(e):
    m = date_re.match(e)
    return m.group(1) if m else ""
order = sorted(range(len(entries)), key=lambda i: (date_key(entries[i]), i))
entries = [entries[i] for i in order]

if len(entries) <= keep:
    to_archive, keep_entries = [], entries
else:
    to_archive, keep_entries = entries[:-keep], entries[-keep:]

year_re = re.compile(r'^##\s+(\d{4})-\d{2}-\d{2}')
buckets = OrderedDict()
for e in to_archive:
    m = year_re.match(e)
    buckets.setdefault(m.group(1) if m else "misc", []).append(e)

for key, es in buckets.items():
    with open(os.path.join(archive_dir, "session-log-%s.md" % key), "a", encoding="utf-8") as af:
        af.write("".join(es))

# Rewrite the live log in chronological order (newest last), self-healing any
# out-of-order entries so a physical tail and the date max agree.
with open(log_path, "w", encoding="utf-8") as f:
    f.write(preamble)
    f.write("".join(keep_entries))

print("ROTATE_OK kept=%d archived=%d" % (len(keep_entries), len(to_archive)))
PY
echo "STEP ROTATE: log bounded · ${SECONDS}s · OK"
