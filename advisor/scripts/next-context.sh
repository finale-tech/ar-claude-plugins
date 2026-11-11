#!/usr/bin/env bash
# next-context.sh — cheap context for the /advisor:next intraday loop.
# Given DOMAIN_PATH (already resolved by preflight.sh), emit the few facts a
# cycle needs so the model never does date/path math in its head: current
# local time, the work-tracker + today's worklog paths, and today's loop
# bookkeeping from .cache/next-state.md (last check-in + minutes since, cycle).
# No domain resolution (preflight owns that), no MCP, no extraction. Safe to run
# every cycle.
#
# Usage: next-context.sh <DOMAIN_PATH>
#
# Stdout on success (key=value lines, final line NEXT_CONTEXT_OK):
#   NOW=<local ISO-8601 with offset>
#   TODAY=YYYY-MM-DD
#   DOW=<Mon..Sun>
#   WORK_TRACKER=<path | NONE>
#   TODAY_WORKLOG=<path | NONE>
#   STATE_PATH=<DOMAIN_PATH>/advisor/.cache/next-state.md
#   STATE_EXISTS=<yes | no>
#   STATE_IS_TODAY=<yes | no>        # state file's date == TODAY
#   LAST_CHECKIN=<ISO | NONE>
#   MINUTES_SINCE=<int | NONE>       # minutes from LAST_CHECKIN to NOW (today only)
#   CYCLE=<int>                      # cycle count recorded in today's state
#   SESSIONLOG_SIG=<bytes:lines | NONE>  # session-log fingerprint for the end-only guard
#   PAST_CUTOFF=<yes | no>           # local hour >= 17: the loop must wind down
#   NEXT_AT=<HH:MM | NONE>           # when the next check-in fires (NOW + INTERVAL_MIN)
#   NEXT_CRON=<"m h dom mon *" | NONE>  # pin the one-shot timer to this; NONE = past the cutoff, schedule nothing
#   LOOP=<on | off>                  # today's state says the loop is running
#   NEXT_JOB_ID=<id | NONE>          # pending one-shot timer recorded in state
#   TASKS_ROOT=<path | NONE>         # status.md -> Domain Sources -> tasks-root
#   THIS_CYCLE=<int>                 # the number of the cycle about to run (record it as `cycle`)
#   TRACKER_PLATE_LINES=<int>        # read only this many lines of the tracker (🔴 + top of 🗃️)
#   WORKERS=<int | UNAVAILABLE>      # live sessions started under TASKS_ROOT
#   WORKER id=… name=… kind=… status=… [waitingFor=…] cwd=…   (one per session)
#   WORKER_STATUS id=… mtime=… | <up to 3 lines of that worker's STATUS.md>
#   NEXT_CONTEXT_OK
# Test-only env: ADVISOR_NOW (ISO-8601 override of NOW), ADVISOR_CUTOFF_HOUR,
# ADVISOR_INTERVAL_MIN (check-in spacing, default 10).
# Exit non-zero with a specific reason on stderr otherwise.
set -euo pipefail

DOMAIN_PATH="${1:?usage: next-context.sh <DOMAIN_PATH>}"

command -v python3 >/dev/null 2>&1 || {
  echo "NEXT_CONTEXT FAILED: python3 not found on PATH." >&2; exit 1; }
[ -d "$DOMAIN_PATH" ] || {
  echo "NEXT_CONTEXT FAILED: DOMAIN_PATH '$DOMAIN_PATH' is not a directory." >&2; exit 1; }
[ -f "$DOMAIN_PATH/advisor/commitments.md" ] || {
  echo "NEXT_CONTEXT FAILED: '$DOMAIN_PATH' has no advisor/commitments.md — not an initialized domain." >&2; exit 1; }

NOW="${ADVISOR_NOW:-$(date '+%Y-%m-%dT%H:%M%z')}"
TODAY="${NOW:0:10}"
if [ -n "${ADVISOR_NOW:-}" ]; then
  DOW="$(python3 -I -c 'import datetime,sys;
print(datetime.date.fromisoformat(sys.argv[1]).strftime("%a"))' "$TODAY")"
else
  DOW="$(date '+%a')"
fi
# The loop shuts itself down at CUTOFF_HOUR (local, 24h). ADVISOR_NOW is a
# test-only override so the cutoff can be exercised without waiting for 5pm.
CUTOFF_HOUR="${ADVISOR_CUTOFF_HOUR:-17}"
if [ "$((10#${NOW:11:2}))" -ge "$CUTOFF_HOUR" ]; then PAST_CUTOFF="yes"; else PAST_CUTOFF="no"; fi

# Check-in spacing lives here and only here. The date math is done here too, so the
# PM just schedules NEXT_CRON; NONE means the next fire would land at/after the cutoff.
# The minute skips :00/:30 (shared by every other scheduled job).
INTERVAL_MIN="${ADVISOR_INTERVAL_MIN:-10}"
NEXT="$(python3 -I -c '
import datetime, sys
now = datetime.datetime.strptime(sys.argv[1], "%Y-%m-%dT%H:%M%z")
t = now + datetime.timedelta(minutes=int(sys.argv[2]))
if t.minute in (0, 30):
    t += datetime.timedelta(minutes=1)
if t.date() != now.date() or t.hour >= int(sys.argv[3]):
    print("NONE|NONE")
else:
    print(f"{t:%H:%M}|{t.minute} {t.hour} {t.day} {t.month} *")
' "$NOW" "$INTERVAL_MIN" "$CUTOFF_HOUR")"
NEXT_AT="${NEXT%%|*}"
NEXT_CRON="${NEXT#*|}"

# A Domain Sources value from status.md: the text after `<key>:`, without the
# trailing " — explanation" the template carries. A value still holding its
# `[placeholder]` counts as not set (same rule as `## You` in preflight.sh), so
# an unfilled template line never reaches a skill as if it were a real path.
source_value() {
  local v
  v="$({ grep -iE "^[[:space:]]*[-*]?[[:space:]]*$1:" "$STATUS" 2>/dev/null || true; } | head -1 | sed -E 's/^[^:]*:[[:space:]]*//; s/[[:space:]]+—.*$//; s/[[:space:]]+$//' | tr -d '\r')"
  case "$v" in ''|\[*) return 0 ;; esac
  printf '%s' "${v/#\~/$HOME}"
}

# work-tracker path from status.md -> Domain Sources -> work-tracker
STATUS="$DOMAIN_PATH/advisor/status.md"
WORK_TRACKER="NONE"
if [ -f "$STATUS" ]; then
  wt="$(source_value work-tracker)"
  if [ -n "$wt" ]; then WORK_TRACKER="$wt"; fi
fi

# tasks root (where background workers live) from status.md -> Domain Sources -> tasks-root
TASKS_ROOT="NONE"
if [ -f "$STATUS" ]; then
  tr_="$(source_value tasks-root)"
  if [ -n "$tr_" ]; then TASKS_ROOT="$tr_"; fi
fi

# today's worklog (written by the full sitrep)
WL="$DOMAIN_PATH/worklog-$TODAY.md"
if [ -f "$WL" ]; then TODAY_WORKLOG="$WL"; else TODAY_WORKLOG="NONE"; fi

# session-log fingerprint — captured at cycle start so `validate.sh next … cycle`
# can detect an illegal mid-cycle append. Only `end` may write the session log; a
# per-cycle entry drifts LAST_SESSION_DATE and makes the next full sitrep under-scan.
SLOG="$DOMAIN_PATH/advisor/session-log.md"
if [ -f "$SLOG" ]; then
  SESSIONLOG_SIG="$(wc -c < "$SLOG" | tr -d ' '):$(wc -l < "$SLOG" | tr -d ' ')"
else
  SESSIONLOG_SIG="NONE"
fi

# loop bookkeeping
STATE="$DOMAIN_PATH/advisor/.cache/next-state.md"
STATE_EXISTS="no"; STATE_IS_TODAY="no"; LAST_CHECKIN="NONE"; MINUTES_SINCE="NONE"; CYCLE="0"
LOOP="off"; NEXT_JOB_ID="NONE"
if [ -f "$STATE" ]; then
  STATE_EXISTS="yes"
  sd="$(grep -iE '^[[:space:]]*[-*]?[[:space:]]*date:' "$STATE" 2>/dev/null | head -1 | sed -E 's/^[^:]*:[[:space:]]*//' | tr -d '\r ')"
  lc="$(grep -iE '^[[:space:]]*[-*]?[[:space:]]*last-checkin:' "$STATE" 2>/dev/null | head -1 | sed -E 's/^[^:]*:[[:space:]]*//' | tr -d '\r ')"
  cy="$(grep -iE '^[[:space:]]*[-*]?[[:space:]]*cycle:' "$STATE" 2>/dev/null | head -1 | sed -E 's/^[^:]*:[[:space:]]*//' | tr -d '\r ')"
  lp="$({ grep -iE '^[[:space:]]*[-*]?[[:space:]]*loop:' "$STATE" 2>/dev/null || true; } | head -1 | sed -E 's/^[^:]*:[[:space:]]*//' | tr -d '\r ')"
  jb="$({ grep -iE '^[[:space:]]*[-*]?[[:space:]]*next-job-id:' "$STATE" 2>/dev/null || true; } | head -1 | sed -E 's/^[^:]*:[[:space:]]*//' | tr -d '\r ')"
  if [ -n "$lc" ]; then LAST_CHECKIN="$lc"; fi
  case "$cy" in ''|*[!0-9]*) : ;; *) CYCLE="$cy" ;; esac
  if [ "$sd" = "$TODAY" ]; then
    if [ "$lp" = "on" ]; then LOOP="on"; fi
    if [ -n "$jb" ]; then NEXT_JOB_ID="$jb"; fi
    STATE_IS_TODAY="yes"
    if [ "$LAST_CHECKIN" != "NONE" ]; then
      MINUTES_SINCE="$(python3 - "$LAST_CHECKIN" <<'PY'
import sys, datetime
raw = sys.argv[1]
for fmt in ("%Y-%m-%dT%H:%M%z", "%Y-%m-%dT%H:%M:%S%z"):
    try:
        dt = datetime.datetime.strptime(raw, fmt)
        now = datetime.datetime.now(dt.tzinfo)
        d = int((now - dt).total_seconds() // 60)
        print(d if d > 0 else 0)
        break
    except ValueError:
        continue
else:
    print("NONE")
PY
)"
    fi
  fi
fi

# This cycle's number. Computed here so the model never does the +1 itself —
# it was observed reporting the *recorded* cycle instead of this one.
if [ "$STATE_IS_TODAY" = "yes" ]; then THIS_CYCLE="$((CYCLE + 1))"; else THIS_CYCLE="1"; fi

# How many lines of the tracker a cycle needs: the 🔴 table plus the top rows of the
# 🗃️ Needs Prioritization (heading line + 12). The tracker grows without bound and
# a cycle runs many times a day, so the PM reads only this slice, never the whole file.
TRACKER_PLATE_LINES="60"
if [ "$WORK_TRACKER" != "NONE" ] && [ -f "$WORK_TRACKER" ]; then
  np="$(awk '/Needs Prioritization/ { print NR; exit }' "$WORK_TRACKER")"
  case "$np" in ''|*[!0-9]*) : ;; *) TRACKER_PLATE_LINES="$((np + 12))" ;; esac
fi

# worker snapshot — every live Claude session started under the tasks root
# (background workers and interactive peers), one WORKER line each, plus the
# first three lines of the worker's STATUS.md. Structured (`claude agents
# --json`), never `claude logs` (a screen scrape). Fail-soft: an unavailable
# `claude agents` must not stop the loop, so it reports UNAVAILABLE instead.
WORKERS_OUT=""
if command -v claude >/dev/null 2>&1 && [ "$TASKS_ROOT" != "NONE" ] && [ -d "$TASKS_ROOT" ]; then
  if raw="$(claude agents --json --cwd "$TASKS_ROOT" 2>/dev/null)"; then
    WORKERS_OUT="$(printf '%s' "$raw" | python3 -I -c '
import json, os, sys, datetime
try:
    rows = json.load(sys.stdin)
except ValueError:
    print("WORKERS=UNAVAILABLE"); sys.exit(0)
print("WORKERS=%d" % len(rows))
for r in rows:
    wid = r.get("id") or (r.get("sessionId") or "-")[:8]
    wait = r.get("waitingFor")
    print("WORKER id=%s name=%s kind=%s status=%s%s cwd=%s" % (
        wid, r.get("name"), r.get("kind"), r.get("status"),
        (" waitingFor=%s" % wait) if wait else "", r.get("cwd")))
    sp = os.path.join(r.get("cwd") or "", "STATUS.md")
    if os.path.isfile(sp):
        mt = datetime.datetime.fromtimestamp(os.path.getmtime(sp)).strftime("%Y-%m-%dT%H:%M")
        with open(sp, errors="replace") as f:
            lines = [l.strip() for l in f.read().splitlines() if l.strip()][:3]
        print("WORKER_STATUS id=%s mtime=%s | %s" % (wid, mt, " | ".join(lines)))
')"
  else
    WORKERS_OUT="WORKERS=UNAVAILABLE"
  fi
else
  WORKERS_OUT="WORKERS=UNAVAILABLE"
fi

echo "NOW=$NOW"
echo "PAST_CUTOFF=$PAST_CUTOFF"
echo "NEXT_AT=$NEXT_AT"
echo "NEXT_CRON=$NEXT_CRON"
echo "LOOP=$LOOP"
echo "NEXT_JOB_ID=$NEXT_JOB_ID"
echo "TASKS_ROOT=$TASKS_ROOT"
echo "THIS_CYCLE=$THIS_CYCLE"
echo "TRACKER_PLATE_LINES=$TRACKER_PLATE_LINES"
printf '%s\n' "$WORKERS_OUT"
echo "TODAY=$TODAY"
echo "DOW=$DOW"
echo "WORK_TRACKER=$WORK_TRACKER"
echo "TODAY_WORKLOG=$TODAY_WORKLOG"
echo "STATE_PATH=$STATE"
echo "STATE_EXISTS=$STATE_EXISTS"
echo "STATE_IS_TODAY=$STATE_IS_TODAY"
echo "LAST_CHECKIN=$LAST_CHECKIN"
echo "MINUTES_SINCE=$MINUTES_SINCE"
echo "CYCLE=$CYCLE"
echo "SESSIONLOG_SIG=$SESSIONLOG_SIG"
if [ "$WORK_TRACKER" = "NONE" ]; then wt_name="none"; else wt_name="$(basename "$WORK_TRACKER")"; fi
echo "STEP NEXT-CONTEXT: cycle=$THIS_CYCLE, since=${MINUTES_SINCE}m, tracker=$wt_name · ${SECONDS}s · OK"
echo "NEXT_CONTEXT_OK"
