#!/usr/bin/env bash
# gather.sh — deterministic local data sweep for the sitrep/am gather phase.
# Runs the session extractor ONCE per day into a stable cache, greps meeting
# transcripts for the user's action items, counts work-tracker todos, and writes
# a manifest plus a source-coverage checklist. Does NOT touch Slack or Jira —
# those need MCP tools the model calls directly (and then checks off in the
# coverage file). Run this once per session; never re-run the extractor to page
# its output.
#
# Usage: gather.sh <mode> <DOMAIN_PATH> <START_YYYY-MM-DD> <END_YYYY-MM-DD> [WORK_TRACKER_PATH]
#                  --names "<a|b>" [--transcripts <dir>]
#   mode          sitrep | am — selects which coverage checklist to emit.
#   --names       the user's names, pipe-separated (preflight's PERSON_ALIASES); required.
#   --transcripts folder of meeting transcripts (status.md → meeting-transcripts); omit to skip that sweep.
#
# Stdout: a short summary; final line is GATHER_OK. Writes into
#   <DOMAIN_PATH>/advisor/.cache/ :
#     sessions-<date>.txt   one stable file per day (extractor output)
#     todo-candidates.txt   transcript grep hits (file:line:text)
#     manifest.txt          machine-readable summary of what was produced
#     coverage.md           source checklist; validate.sh gates on it
#
# Path override (for testing): ADVISOR_EXTRACT_SCRIPT
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTRACT_SCRIPT="${ADVISOR_EXTRACT_SCRIPT:-$SCRIPT_DIR/extract_sessions.py}"

NAMES=""
TRANSCRIPTS_DIR=""
POS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --names) NAMES="${2:?--names needs a value}"; shift 2 ;;
    --transcripts) TRANSCRIPTS_DIR="${2:?--transcripts needs a directory}"; shift 2 ;;
    *) POS+=("$1"); shift ;;
  esac
done
set -- ${POS[@]+"${POS[@]}"}
[ -n "$NAMES" ] || { echo "gather.sh: --names is required (preflight's PERSON_ALIASES)" >&2; exit 2; }
# Escape regex metacharacters in each name (e.g. "A.R."), keeping | as the separator.
NAME_RE="$(printf '%s' "$NAMES" | sed -E 's/[][\.*^$(){}?+]/\\&/g')"

MODE="${1:?usage: gather.sh <mode> <DOMAIN_PATH> <start> <end> [worktracker] --names <a|b> [--transcripts <dir>]}"
DOMAIN_PATH="${2:?DOMAIN_PATH required}"
START="${3:?start date required}"
END="${4:?end date required}"
WORK_TRACKER="${5:-}"

case "$MODE" in
  sitrep|am) ;;
  *) echo "gather.sh: mode must be 'sitrep' or 'am' (got '$MODE')" >&2; exit 2 ;;
esac

CACHE="$DOMAIN_PATH/advisor/.cache"
mkdir -p "$CACHE"

# --- Phase A: sessions per date (single extraction each; stable cache) ---
dates="$(python3 - "$START" "$END" <<'PY'
import sys
from datetime import datetime, timedelta
try:
    s = datetime.strptime(sys.argv[1], "%Y-%m-%d")
    e = datetime.strptime(sys.argv[2], "%Y-%m-%d")
except ValueError as ex:
    sys.stderr.write("gather.sh: bad date (%s)\n" % ex); sys.exit(2)
if e < s:
    sys.stderr.write("gather.sh: end date is before start date\n"); sys.exit(2)
d = s
while d <= e:
    print(d.strftime("%Y-%m-%d")); d += timedelta(days=1)
PY
)"

session_days=0
active_dates=""
worklog_needed=""
worklog_existing=""
# Today is never "closed" — sitrep's range now runs through NOW, so a same-day
# rerun must re-narrate today's worklog with whatever's new, not skip it because
# an earlier-today run already wrote a (now-stale) file for that date.
SYSTEM_TODAY="$(date '+%Y-%m-%d')"
for d in $dates; do
  out="$CACHE/sessions-$d.txt"
  if ! python3 "$EXTRACT_SCRIPT" "$d" > "$out" 2>/dev/null; then
    : > "$out"
  fi
  if grep -q "Sessions found: 0" "$out" 2>/dev/null; then
    :
  elif [ -s "$out" ]; then
    session_days=$((session_days + 1))
    active_dates="$active_dates $d"
    # Closed worklist: a past active date needs a worklog only if it has none
    # yet. Today is the exception — always regenerate it while the day is open.
    if [ "$d" = "$SYSTEM_TODAY" ]; then
      worklog_needed="$worklog_needed $d"
    elif [ -f "$DOMAIN_PATH/worklog-$d.md" ]; then
      worklog_existing="$worklog_existing $d"
    else
      worklog_needed="$worklog_needed $d"
    fi
  fi
done
active_dates="${active_dates# }"; worklog_needed="${worklog_needed# }"; worklog_existing="${worklog_existing# }"

# --- Phase B: transcript todo candidates (single sweep) ---
CAND="$CACHE/todo-candidates.txt"
: > "$CAND"
if [ -n "$TRANSCRIPTS_DIR" ] && [ -d "$TRANSCRIPTS_DIR" ]; then
  grep -rEin --include='*.md' \
    -e "\[[ xX]\] \*\*($NAME_RE)" \
    -e "($NAME_RE).*(will|should|I'll|can take|to take|to pick|to create|to review|to check|to investigate|to complete|to file|to document|to send|to set up|to learn|to propose|to sync|to own|to update|to finish|to prepare)" \
    -e "($NAME_RE).*(own|point of contact|POC)" \
    "$TRANSCRIPTS_DIR" >> "$CAND" 2>/dev/null || true
fi
cand_count="$(wc -l < "$CAND" | tr -d ' ')"

# --- Phase C: work-tracker open/done counts (markdown AND HTML checkboxes) ---
# Counts `- [ ]`/`- [x]` markdown checkboxes and `<input type="checkbox">` HTML
# checkboxes (the tracker's format), so the count reflects real open items.
if [ -n "$WORK_TRACKER" ] && [ -f "$WORK_TRACKER" ]; then
  md_open="$( { grep -cE '^[[:space:]]*[-*] \[ \]' "$WORK_TRACKER" || true; } )"
  md_done="$( { grep -cE '^[[:space:]]*[-*] \[[xX]\]' "$WORK_TRACKER" || true; } )"
  html_all="$( { grep -oiE '<input[^>]*type="checkbox"' "$WORK_TRACKER" || true; } | wc -l | tr -d ' ')"
  html_done="$( { grep -oiE '<input[^>]*type="checkbox"[^>]*checked' "$WORK_TRACKER" || true; } | wc -l | tr -d ' ')"
  md_open="${md_open:-0}"; md_done="${md_done:-0}"
  wt_open=$((md_open + html_all - html_done))
  wt_done=$((md_done + html_done))

  # Assertion (pipeline contract, guideline 1): a non-empty tracker that yields
  # zero checkboxes of any recognized kind means the counter cannot parse it —
  # fail loudly rather than emit a misleading 0.
  if [ -s "$WORK_TRACKER" ] && [ "$((wt_open + wt_done))" -eq 0 ]; then
    echo "gather.sh: work-tracker '$WORK_TRACKER' is non-empty but matched no todo checkboxes (expected markdown '- [ ]' or '<input type=\"checkbox\">'). Counter cannot parse this tracker — fix the count pattern or the tracker format." >&2
    exit 3
  fi
else
  wt_open="unknown"; wt_done="unknown"
fi

# --- Phase C2: active Slack thread anchors ---
# A windowed slack_read_channel returns only messages whose own ts is in-window,
# so a thread whose PARENT predates the window never appears — even when it has
# fresh in-window replies. Long-running escalation threads must therefore be
# re-read directly by thread_ts, the same way active PRs get `gh pr view` and
# active tickets get `getJiraIssue`. Extract (channel_id, thread_ts) from the
# Slack permalinks on the work-tracker's OPEN rows so the model has an exact,
# deterministic worklist to slack_read_thread. Resolved/checked rows are skipped.
THREADS="$CACHE/active-threads.txt"
: > "$THREADS"
if [ -n "$WORK_TRACKER" ] && [ -f "$WORK_TRACKER" ]; then
  python3 - "$WORK_TRACKER" > "$THREADS" <<'PY' || true
import sys, re
path = sys.argv[1]
url_re = re.compile(r'https://[^\s)"\']*/archives/([A-Z0-9]+)/p(\d+)(?:[^\s)"\']*?thread_ts=([0-9.]+))?')
seen = set()
for line in open(path, encoding='utf-8', errors='replace'):
    l = line.strip()
    is_md_open   = bool(re.match(r'^[-*]\s*\[ \]', l))
    is_md_done   = bool(re.match(r'^[-*]\s*\[[xX]\]', l))
    is_html      = 'type="checkbox"' in l
    is_html_done = bool(is_html and re.search(r'type="checkbox"[^>]*checked', l))
    open_row = is_md_open or (is_html and not is_html_done)
    if not open_row or is_md_done or is_html_done:
        continue
    for cid, pdigits, tts in url_re.findall(l):
        if not tts:
            tts = pdigits[:-6] + '.' + pdigits[-6:] if len(pdigits) > 6 else pdigits
        key = (cid, tts)
        if key in seen:
            continue
        seen.add(key)
        print(f"{cid}\t{tts}")
PY
fi
thread_count="$(wc -l < "$THREADS" | tr -d ' ')"

# --- Phase D: manifest ---
MANIFEST="$CACHE/manifest.txt"
{
  echo "mode: $MODE"
  echo "range: $START..$END"
  echo "generated: $(date '+%Y-%m-%d %H:%M')"
  echo "session_days_with_activity: $session_days"
  echo "active_dates: ${active_dates:-none}"
  echo "worklog_dates_needed: ${worklog_needed:-none}"
  echo "worklog_dates_existing: ${worklog_existing:-none}"
  echo "sessions_cache_glob: $CACHE/sessions-<date>.txt"
  echo "todo_candidates_file: $CAND"
  echo "todo_candidate_lines: $cand_count"
  echo "worktracker: ${WORK_TRACKER:-none}"
  echo "worktracker_open_checkboxes: $wt_open"
  echo "worktracker_checked_checkboxes: $wt_done"
  echo "active_threads_file: $THREADS"
  echo "active_thread_anchors: $thread_count"
} > "$MANIFEST"

# --- Phase E: source-coverage checklist (mode-specific) ---
# gather.sh pre-checks the local sources it just completed. The model MUST check
# off every remaining box as it completes that source. validate.sh fails while
# any box is unchecked — this is what prevents silently skipping a source.
COVERAGE="$CACHE/coverage.md"
{
  echo "# Source coverage — mode=$MODE range=$START..$END (generated $(date '+%Y-%m-%d %H:%M'))"
  echo "# gather.sh marks local sources [x]. Check off the rest as you complete each."
  echo "# validate.sh fails while any box below is unchecked."
  echo "# A source that is genuinely unreachable is marked '- [~] <name> — unreachable: <reason>' (never left '[ ]')."
  echo
  echo "- [x] worklog_extraction"
  # Cowork writes its transcripts to its own per-session tree, outside the
  # projects dir the extractor reads, so worklog_extraction above covers Claude
  # Code sessions only. Declared unreachable rather than left unchecked: on a
  # Cowork day the extractor finds no sessions, which is indistinguishable from
  # an idle day unless the gap says so itself. Cowork work is narrated by hand
  # into worklog-<date>.md (append a time-of-day section; never pre-create the
  # file on a mixed day — its existence is what suppresses extraction).
  echo "- [~] cowork_sessions — unreachable: Cowork transcripts live outside the extractor's projects dir; narrate that work by hand into worklog-<date>.md"
  echo "- [x] transcript_scan"
  if [ "$MODE" = "sitrep" ]; then
    echo "- [ ] slack_channels"
    echo "- [ ] slack_dms"
    echo "- [ ] slack_active_threads"
    echo "- [ ] slack_catchall_sweep"
    echo "- [ ] jira_scanned"
    echo "- [ ] github_review_requests"
    echo "- [ ] todo_file_updated"
  else
    echo "- [x] worktracker_read"
    echo "- [ ] session_log_read"
    echo "- [ ] commitments_read"
    echo "- [ ] jira_board"
    echo "- [ ] daily_brief_written"
  fi
} > "$COVERAGE"

echo "manifest: $MANIFEST"
echo "coverage_checklist: $COVERAGE"
echo "active_threads_file: $THREADS"
echo "sessions_with_activity: $session_days | todo_candidates: $cand_count | worktracker_open: $wt_open | active_threads: $thread_count"
echo "worklog_dates_needed: ${worklog_needed:-none}"
echo "STEP GATHER: $START..$END, ${session_days} active day(s), ${cand_count} candidates, worklog_needed=${worklog_needed:-none}, worktracker_open=${wt_open} · ${SECONDS}s · OK"
echo "GATHER_OK"
