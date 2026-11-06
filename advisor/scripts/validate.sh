#!/usr/bin/env bash
# validate.sh — the gate that runs before a sitrep/am session is allowed to
# finish. Fails hard (non-zero) if any mandatory source was left unchecked, or,
# in am mode, if the daily brief is missing/empty/incomplete. Run the script
# itself; do not reimplement its checks inline, and do not assume its result —
# its exit code is authoritative.
#
# Usage: validate.sh <mode> <DOMAIN_PATH> [BRIEF_DATE_YYYY-MM-DD]
#   mode        sitrep | am | next
#   BRIEF_DATE  required for am mode; the date of daily-brief-<date>.md
#   next mode   validate.sh next <DOMAIN_PATH> cycle <SESSIONLOG_SIG>  (per-cycle guard)
#               validate.sh next <DOMAIN_PATH> end                     (day-wrap check)
#
# Stdout on success: "SITREP_OK", "BRIEF_OK <path>", "NEXT_OK", or "NEXT_END_OK".
# Exit non-zero listing exactly what is missing otherwise.
set -euo pipefail

MODE="${1:?usage: validate.sh <mode> <DOMAIN_PATH> [brief_date]}"
DOMAIN_PATH="${2:?DOMAIN_PATH required}"
BRIEF_DATE="${3:-}"

CACHE="$DOMAIN_PATH/advisor/.cache"
COVERAGE="$CACHE/coverage.md"

fail() { echo "VALIDATE FAILED: $*" >&2; exit 1; }

case "$MODE" in
  sitrep)
    MANIFEST="$CACHE/manifest.txt"
    [ -f "$COVERAGE" ] || fail "no coverage checklist at $COVERAGE — run gather.sh first."
    [ -f "$MANIFEST" ] || fail "no manifest at $MANIFEST — run gather.sh first."
    # Correctness, not just presence: the gate must reflect a gather run TODAY, not
    # stale boxes ticked on a prior day.
    TODAY="$(date '+%Y-%m-%d')"
    if ! grep -qE "^generated: $TODAY" "$MANIFEST"; then
      gen="$(grep -E '^generated:' "$MANIFEST" | head -1 || true)"
      fail "gather manifest is stale ($gen; expected today $TODAY) — re-run gather.sh so coverage reflects this run."
    fi
    # Any unchecked box means a source was skipped.
    unchecked="$(grep -nE '^- \[ \]' "$COVERAGE" || true)"
    if [ -n "$unchecked" ]; then
      echo "VALIDATE FAILED: these sources were not checked off in $COVERAGE:" >&2
      echo "$unchecked" | sed 's/^/  /' >&2
      exit 1
    fi
    # A source may be marked explicitly unreachable ('- [~] name — <reason>') instead of
    # done, but only WITH a reason. A bare '[~]' with no reason is not acceptable — that
    # is a silent skip wearing a marker.
    badskip="$(grep -nE '^- \[~\][[:space:]]+[^[:space:]]+[[:space:]]*$' "$COVERAGE" || true)"
    if [ -n "$badskip" ]; then
      echo "VALIDATE FAILED: these sources are marked unreachable with no reason in $COVERAGE:" >&2
      echo "$badskip" | sed 's/^/  /' >&2
      exit 1
    fi
    echo "STEP VALIDATE(sitrep): gather fresh, all sources covered · ${SECONDS}s · OK"
    echo "SITREP_OK"
    ;;
  am)
    # am reads sitrep's facts and does not gather, so there is no coverage gate —
    # validate only that the brief is present and complete.
    [ -n "$BRIEF_DATE" ] || fail "am mode requires a brief date argument (YYYY-MM-DD)."
    BRIEF="$DOMAIN_PATH/advisor/daily-brief-$BRIEF_DATE.md"
    [ -f "$BRIEF" ] || fail "daily brief not found at $BRIEF."
    [ -s "$BRIEF" ] || fail "daily brief $BRIEF is empty (truncated write?)."
    missing=""
    for h in \
      "## Yesterday's Work" \
      "## Artifact Coverage" \
      "## Commitment" \
      "## Jira Board State" \
      "## Needs Prioritization" \
      "## Proposed Actions"
    do
      grep -qF "$h" "$BRIEF" || missing="$missing\n  - $h"
    done
    if [ -n "$missing" ]; then
      echo "VALIDATE FAILED: daily brief $BRIEF is missing required sections:" >&2
      printf "%b\n" "$missing" >&2
      exit 1
    fi
    echo "STEP VALIDATE(am): brief sections present · ${SECONDS}s · OK"
    echo "BRIEF_OK $BRIEF"
    ;;
  next)
    # The intraday loop must not touch session-log.md except in `end` mode.
    # preflight.sh derives LAST_SESSION_DATE from the log's `## YYYY-MM-DD`
    # headings, so a mid-cycle append silently drifts it and makes the next full
    # sitrep under-scan. This gate makes the "only `end` writes the log" rule a
    # hard exit code instead of prose the model is merely trusted to follow.
    KIND="${3:?next mode requires a kind: 'cycle' or 'end'}"
    SLOG="$DOMAIN_PATH/advisor/session-log.md"
    cur="NONE"
    if [ -f "$SLOG" ]; then
      cur="$(wc -c < "$SLOG" | tr -d ' '):$(wc -l < "$SLOG" | tr -d ' ')"
    fi
    case "$KIND" in
      cycle)
        START_SIG="${4:?next cycle guard requires the SESSIONLOG_SIG captured at Step 1}"
        if [ "$cur" != "$START_SIG" ]; then
          fail "next wrote to session-log.md during a non-end cycle (sig $START_SIG -> $cur). Only 'end' may write the log — a mid-cycle entry drifts LAST_SESSION_DATE and makes the next full sitrep under-scan. Revert the session-log change."
        fi
        echo "STEP VALIDATE(next/cycle): session-log unchanged · ${SECONDS}s · OK"
        echo "NEXT_OK"
        ;;
      end)
        TODAY="$(date '+%Y-%m-%d')"
        [ -f "$SLOG" ] || fail "next end found no session-log.md at $SLOG."
        grep -qE "^## $TODAY" "$SLOG" 2>/dev/null || fail "next end wrote no session-log entry dated $TODAY — the day-wrap entry is missing. Append it before rotate-log.sh."
        echo "STEP VALIDATE(next/end): day-wrap entry present · ${SECONDS}s · OK"
        echo "NEXT_END_OK"
        ;;
      *)
        fail "next kind must be 'cycle' or 'end' (got '$KIND')."
        ;;
    esac
    ;;
  *)
    fail "mode must be 'sitrep', 'am', or 'next' (got '$MODE')."
    ;;
esac
