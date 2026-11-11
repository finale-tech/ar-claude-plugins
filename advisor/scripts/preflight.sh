#!/usr/bin/env bash
# preflight.sh — resolve the advisor domain and run fail-hard environment checks.
# Runs before any sitrep/am work. No silent skips: any failure stops the run with
# a specific reason.
#
# Usage: preflight.sh [domain_name]
#   domain_name  optional; the value from a `--domain <name>` flag. Domains live
#                at a fixed place: ${ADVISOR_HOME:-~/.advisor}/<name>/. With a
#                name, use that folder; without one, use the only domain there
#                (none or several → fail and list them).
#
# Stdout on success (key=value lines, final line PREFLIGHT_OK):
#   DOMAIN_PATH=<absolute path>
#   LAST_SESSION_DATE=<YYYY-MM-DD | empty>
#   TODAY=YYYY-MM-DD
#   YESTERDAY=YYYY-MM-DD
#   TODAY_DOW=<Mon..Sun>
#   NOW=<ISO8601 local time with offset>
#   NOW_EPOCH=<unix seconds>
#   WINDOW_START_EPOCH=<unix seconds — live-scan lower bound, last scan − 24h>
#   WINDOW_START_DATE=<YYYY-MM-DD — calendar-date form of WINDOW_START_EPOCH>
#   PERSON_NAME=<full name>                from `## You` in the domain's advisor/status.md
#   PERSON_ALIASES=<a|b|c>                 names to match in transcripts and Slack (default: first name)
#   SLACK_USER_ID=<id>   SLACK_USERNAME=<handle>   GITHUB_USERNAME=<login>
#   LIBRARY_PATH=<absolute path>           the plugin's library/ folder (general text)
#   ROLE_DAY=<int | empty>                 calendar days since `start_date:` in status.md, first day = 1
#   ROLE_WEEK=<int | empty>                week of the role, counted from the Monday of the start week
#   PREFLIGHT_OK
# Exit non-zero with a specific reason on stderr otherwise.
#
# Path overrides (for testing) — env vars take precedence over the defaults:
#   ADVISOR_HOME, ADVISOR_EXTRACT_SCRIPT, ADVISOR_TODOS_PROCESS, ADVISOR_LIBRARY
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADVISOR_HOME="${ADVISOR_HOME:-$HOME/.advisor}"
EXTRACT_SCRIPT="${ADVISOR_EXTRACT_SCRIPT:-$SCRIPT_DIR/extract_sessions.py}"
TODOS_PROCESS="${ADVISOR_TODOS_PROCESS:-$SCRIPT_DIR/../references/process.md}"
LIBRARY="${ADVISOR_LIBRARY:-$SCRIPT_DIR/../library}"

DOMAIN_ARG=""
REQUIRE_FRESH_TRACKER=0
for a in "$@"; do
  case "$a" in
    --require-fresh-tracker) REQUIRE_FRESH_TRACKER=1 ;;
    --*) : ;;                                  # ignore other flags
    *) [ -z "$DOMAIN_ARG" ] && DOMAIN_ARG="$a" || true ;;
  esac
done

command -v python3 >/dev/null 2>&1 || {
  echo "PREFLIGHT FAILED: python3 not found on PATH." >&2; exit 1; }

# Resolve DOMAIN_PATH by convention: every domain is a folder under ADVISOR_HOME
# that holds advisor/commitments.md. Any failure prints a specific PREFLIGHT
# FAILED reason to stderr and exits non-zero (set -e then aborts the outer
# script via the failed command substitution).
DOMAIN_PATH="$(python3 - "$ADVISOR_HOME" "$DOMAIN_ARG" <<'PY'
import os, sys
home, domain_arg = sys.argv[1], sys.argv[2]
def is_domain(p):
    return os.path.isfile(os.path.join(p, "advisor", "commitments.md"))
names = sorted(
    n for n in (os.listdir(home) if os.path.isdir(home) else [])
    if not n.startswith(".") and is_domain(os.path.join(home, n))
)
avail = ", ".join(names) or "(none)"
if domain_arg:
    p = os.path.join(home, domain_arg)
    if not is_domain(p):
        sys.stderr.write("PREFLIGHT FAILED: no advisor domain '%s' in %s. Available: %s\n" % (domain_arg, home, avail)); sys.exit(4)
    print(p); sys.exit(0)
if len(names) == 1:
    print(os.path.join(home, names[0])); sys.exit(0)
if not names:
    sys.stderr.write("PREFLIGHT FAILED: no advisor domain in %s — run /advisor:create <name> first.\n" % home); sys.exit(5)
sys.stderr.write("PREFLIGHT FAILED: several domains in %s (%s) — pass --domain <name>.\n" % (home, avail)); sys.exit(5)
PY
)"

[ -n "$DOMAIN_PATH" ] || { echo "PREFLIGHT FAILED: could not resolve DOMAIN_PATH." >&2; exit 1; }
[ -f "$DOMAIN_PATH/advisor/commitments.md" ] || {
  echo "PREFLIGHT FAILED: '$DOMAIN_PATH' has no advisor/commitments.md — not an initialized domain." >&2; exit 1; }

# Identity: who the scans look for. Set once in the `## You` section of the
# domain's advisor/status.md, so no skill or script hardcodes a name or account
# ID. A blank field, or one still holding its `[placeholder]`, counts as missing.
STATUS="$DOMAIN_PATH/advisor/status.md"
[ -f "$STATUS" ] || {
  echo "PREFLIGHT FAILED: '$DOMAIN_PATH' has no advisor/status.md." >&2; exit 1; }
PERSON_OUT="$(python3 - "$STATUS" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
m = re.search(r'^## You[ \t]*\n(.*?)(?=^## |\Z)', text, re.M | re.S)
if not m:
    sys.stderr.write("PREFLIGHT FAILED: %s has no '## You' section — add one with name, aliases, slack_user_id, slack_username, github_username (/advisor:help shows it).\n" % path); sys.exit(6)
fields = {}
for line in m.group(1).splitlines():
    mm = re.match(r'^\s*-\s*([a-z_]+):\s*(.*?)\s*$', line)
    if mm:
        fields[mm.group(1)] = mm.group(2)
def val(k):
    v = fields.get(k, "").strip()
    return "" if (not v or v.startswith("[")) else v
need = ["name", "slack_user_id", "slack_username", "github_username"]
missing = [k for k in need if not val(k)]
if missing:
    sys.stderr.write("PREFLIGHT FAILED: '## You' in %s is missing %s — fill it in.\n" % (path, ", ".join(missing))); sys.exit(6)
aliases = [a.strip() for a in val("aliases").split(",") if a.strip()] or [val("name").split()[0]]
print("PERSON_NAME=%s" % val("name"))
print("PERSON_ALIASES=%s" % "|".join(aliases))
print("SLACK_USER_ID=%s" % val("slack_user_id"))
print("SLACK_USERNAME=%s" % val("slack_username"))
print("GITHUB_USERNAME=%s" % val("github_username"))
PY
)"

# Role clock: the playbook is indexed by week, so the week comes from a recorded
# start date, never from a guess. `start_date:` sits in the front matter of
# status.md. It is optional: blank, missing, or still a `[placeholder]` leaves
# ROLE_DAY and ROLE_WEEK empty. A value that is not a date is an error.
ROLE_OUT="$(python3 - "$STATUS" <<'PY'
import datetime, re, sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
m = re.search(r'^start_date:[ \t]*(.*?)[ \t]*$', text, re.M)
raw = m.group(1) if m else ""
if not raw or raw.startswith("["):
    print("ROLE_DAY="); print("ROLE_WEEK="); sys.exit(0)
try:
    start = datetime.date.fromisoformat(raw)
except ValueError:
    sys.stderr.write("PREFLIGHT FAILED: start_date in %s is '%s' — use YYYY-MM-DD, or leave it blank.\n" % (path, raw)); sys.exit(6)
today = datetime.date.today()
if today < start:
    print("ROLE_DAY=0"); print("ROLE_WEEK=0"); sys.exit(0)
week_one_monday = start - datetime.timedelta(days=start.weekday())
print("ROLE_DAY=%d" % ((today - start).days + 1))
print("ROLE_WEEK=%d" % ((today - week_one_monday).days // 7 + 1))
PY
)"

# The domain's operating-manual.md holds every pattern, instinct and rule in
# full. A heading there with no text of its own stops the run here rather than
# letting a skill coach against a name with no text. library.sh prints the list
# (it would also join a heading to a library entry of the same name, should the
# library ever carry general manual entries again).
[ -d "$LIBRARY" ] || {
  echo "PREFLIGHT FAILED: library not found at $LIBRARY." >&2; exit 1; }
LIBRARY_PATH="$(cd "$LIBRARY" && pwd)"
ADVISOR_LIBRARY="$LIBRARY_PATH" bash "$SCRIPT_DIR/library.sh" check "$DOMAIN_PATH" >/dev/null || {
  echo "PREFLIGHT FAILED: the domain's operating-manual.md has a heading with no text (list above)." >&2; exit 1; }

# session-log paths — used by am's freshness gate below and by LAST_SESSION_DATE.
LOG="$DOMAIN_PATH/advisor/session-log.md"
ARCHIVE_DIR="$DOMAIN_PATH/advisor/archive"

# am passes --require-fresh-tracker: refuse to run unless this morning's full sitrep
# has logged a run today. The signal is session-log.md (automation-owned run-state):
# a today-dated "— Sitrep" entry — never the work-tracker, which the user hand-edits
# (so its mtime/contents can't serve as a freshness proxy). This makes am's freshness
# dependency a deterministic exit code, not a judgment the model is trusted to make.
if [ "$REQUIRE_FRESH_TRACKER" = "1" ]; then
  TODAY="$(date '+%Y-%m-%d')"
  if ! { [ -f "$LOG" ] && grep -qE "^## ${TODAY} .*Sitrep" "$LOG"; }; then
    echo "PREFLIGHT FAILED: no sitrep entry for ${TODAY} in session-log — run /advisor:sitrep first; am reads its facts." >&2
    exit 1
  fi
fi

[ -f "$EXTRACT_SCRIPT" ] || {
  echo "PREFLIGHT FAILED: session extractor not found at $EXTRACT_SCRIPT." >&2; exit 1; }
[ -f "$TODOS_PROCESS" ] || {
  echo "PREFLIGHT FAILED: todos process reference not found at $TODOS_PROCESS." >&2; exit 1; }

# Most recent dated session-log entry, by DATE — not physical order. Rotation
# moves old entries to the archive and the live file can be out of order, so a
# physical `tail` picks the wrong date. Take the max ISO date across the live
# log AND the archive. Empty if no dated entries anywhere.
LAST_SESSION_DATE="$(
  {
    [ -f "$LOG" ] && grep -hEo '^## [0-9]{4}-[0-9]{2}-[0-9]{2}' "$LOG" 2>/dev/null || true
    for f in "$ARCHIVE_DIR"/session-log-*.md; do
      [ -f "$f" ] && grep -hEo '^## [0-9]{4}-[0-9]{2}-[0-9]{2}' "$f" 2>/dev/null || true
    done
  } | sed 's/^## //' | sort | tail -n 1
)"

# Dates the skills need, resolved once here so no skill does calendar math in its
# head (or shells out for it). `date '+%Y-%m-%d'` and `'+%a'` are portable, but
# yesterday needs date ARITHMETIC and the two forms are mutually incompatible:
# BSD/macOS wants `date -v-1d`, GNU/Linux wants `date -d yesterday`, and each
# errors on the other. Advisor runs on macOS under Claude Code and on Linux in the
# Cowork sandbox, so use python3 — already required above — and stay portable.
TODAY="$(date '+%Y-%m-%d')"
TODAY_DOW="$(date '+%a')"
YESTERDAY="$(python3 -c 'import datetime; print((datetime.date.today() - datetime.timedelta(days=1)).isoformat())')"
# NOW is the live upper bound for windowed scans (sitrep's "through this minute"
# range) — a single authoritative timestamp so no skill computes or pads its own.
# `+%s`/`+%Y-%m-%dT%H:%M:%S%z` are pure formatting (unlike date ARITHMETIC), so
# they're portable across the BSD date on macOS and GNU date in the Cowork sandbox.
NOW="$(date '+%Y-%m-%dT%H:%M:%S%z')"
NOW_EPOCH="$(date '+%s')"

# WINDOW_START is sitrep's live-scan lower bound: the LAST scan's own timestamp
# minus 24h — a fixed overlap buffer. Every run deliberately re-covers the tail
# of the previous run's window (harmless: dedup absorbs the repeats), so a
# boundary/timezone/granularity gap can never silently open between two
# consecutive runs. Anchored to the cache manifest's `generated:` line (written
# fresh by gather.sh every run, minute-precision) rather than LAST_SESSION_DATE
# (day-precision only) — but the cache is ephemeral (can be cleared, or predate
# a real multi-day gap), so it's clamped to never land later than the day after
# LAST_SESSION_DATE: if the manifest looks fresher than that floor, trust the
# floor instead, so a real gap is never silently under-scanned for cache reasons.
MANIFEST="$DOMAIN_PATH/advisor/.cache/manifest.txt"
WINDOW_START_EPOCH="$(python3 - "$MANIFEST" "$LAST_SESSION_DATE" "$NOW_EPOCH" <<'PY'
import datetime, re, sys
manifest_path, last_session_date, now_epoch = sys.argv[1], sys.argv[2], int(sys.argv[3])

manifest_start = now_epoch - 86400  # bootstrap default: no prior manifest yet
try:
    with open(manifest_path, encoding='utf-8') as f:
        for line in f:
            m = re.match(r'^generated:\s*(\d{4}-\d{2}-\d{2} \d{2}:\d{2})', line)
            if m:
                dt = datetime.datetime.strptime(m.group(1), '%Y-%m-%d %H:%M')
                manifest_start = int(dt.timestamp()) - 86400
                break
except FileNotFoundError:
    pass

if last_session_date:
    d = datetime.date.fromisoformat(last_session_date) + datetime.timedelta(days=1)
    floor = int(datetime.datetime.combine(d, datetime.time()).timestamp())
    window_start = min(manifest_start, floor)
else:
    window_start = manifest_start

print(window_start)
PY
)"
WINDOW_START_DATE="$(python3 -c "import datetime; print(datetime.datetime.fromtimestamp($WINDOW_START_EPOCH).date().isoformat())")"

echo "DOMAIN_PATH=$DOMAIN_PATH"
echo "LAST_SESSION_DATE=$LAST_SESSION_DATE"
echo "TODAY=$TODAY"
echo "YESTERDAY=$YESTERDAY"
echo "TODAY_DOW=$TODAY_DOW"
echo "NOW=$NOW"
echo "NOW_EPOCH=$NOW_EPOCH"
echo "WINDOW_START_EPOCH=$WINDOW_START_EPOCH"
echo "WINDOW_START_DATE=$WINDOW_START_DATE"
echo "$PERSON_OUT"
echo "LIBRARY_PATH=$LIBRARY_PATH"
echo "$ROLE_OUT"
echo "STEP PREFLIGHT: domain=$(basename "$DOMAIN_PATH"), last_session=${LAST_SESSION_DATE:-none} · ${SECONDS}s · OK"
echo "PREFLIGHT_OK"
